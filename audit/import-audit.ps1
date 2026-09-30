<#
.SYNOPSIS
  Audit a Windows PE (exe/dll) for Win8+ only API imports - the hard gate for
  "will this binary start on Windows 7".

.DESCRIPTION
  Runs dumpbin /imports on the given file(s) and matches every imported
  function against a blacklist of Win8+/Win10-only APIs. Any hit means the
  Windows 7 loader will fail (procedure entry point popup / silent exit).

  Requirements: Visual Studio (dumpbin.exe). The script locates dumpbin via
  vswhere or common BuildTools paths; override with -DumpbinPath.

.EXAMPLE
  .\import-audit.ps1 -Path build-cuda\bin\Release\llama-server.exe
  .\import-audit.ps1 -Path .\engine\ -DumpbinPath "C:\...\dumpbin.exe"
#>
param(
  [Parameter(Mandatory=$true)][string]$Path,
  [string]$DumpbinPath = ""
)

$ErrorActionPreference = "Stop"

# ---- Win8+/Win10-only API blacklist (kernel32/user32/etc. level) ----
$blacklist = @(
  "SetThreadInformation", "GetThreadInformation",
  "SetThreadDescription", "GetThreadDescription",
  "GetSystemTimePreciseAsFileTime",
  "WaitOnAddress", "WakeByAddressAll", "WakeByAddressSingle",
  "SetDefaultDllDirectories", "SetThreadGroupAffinityEx",
  "CreateFile2", "CreateFileMapping2",
  "PrefetchVirtualMemory",
  "MapViewOfFile3", "VirtualAlloc2", "VirtualAlloc2FromApp",
  "GetOverlappedResultEx",
  "GetCurrentThreadStackLimits", "SetProcessMitigationPolicy",
  "SetThreadSelectedCpuSets", "GetThreadSelectedCpuSets",
  "SetProcessDefaultCpuSets", "GetProcessDefaultCpuSets",
  "GetDpiForWindow", "GetDpiForSystem", "GetSystemMetricsForDpi",
  "SetProcessDpiAwarenessContext", "AdjustWindowRectExForDpi",
  "AreDpiAwarenessContextsEqual", "EnableNonClientDpiSupport",
  "GetAwarenessFromDpiAwarenessContext", "GetThreadDpiAwarenessContext",
  "AppPolicyGetThreadInitializationType", "AppPolicyGetProcessTerminationMethod"
)
$blRegex = ($blacklist | ForEach-Object { [regex]::Escape($_) }) -join "|"

# Known-good import DLLs for a Win7-clean binary (system + our runtime deps)
$okDlls = @("kernel32.dll","user32.dll","shell32.dll","advapi32.dll","ws2_32.dll",
            "ole32.dll","oleaut32.dll","gdi32.dll","comdlg32.dll","shlwapi.dll",
            "msvcrt.dll","ntdll.dll","iphlpapi.dll","userenv.dll","dbghelp.dll",
            "version.dll","winmm.dll","psapi.dll","crypt32.dll","bcrypt.dll",
            "secur32.dll","netapi32.dll","setupapi.dll","wintrust.dll")

function Find-Dumpbin {
  param([string]$Override)
  if ($Override -and (Test-Path $Override)) { return $Override }
  $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
  if (Test-Path $vswhere) {
    $vsRoot = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
    if ($vsRoot) {
      $hits = Get-ChildItem -Path (Join-Path $vsRoot "VC\Tools\MSVC") -Recurse -Filter dumpbin.exe -ErrorAction SilentlyContinue |
              Where-Object { $_.FullName -match "Hostx64\\x64" } | Select-Object -First 1
      if ($hits) { return $hits.FullName }
    }
  }
  $guess = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC"
  if (Test-Path $guess) {
    $hit = Get-ChildItem -Path $guess -Recurse -Filter dumpbin.exe -ErrorAction SilentlyContinue |
           Where-Object { $_.FullName -match "Hostx64\\x64" } | Select-Object -First 1
    if ($hit) { return $hit.FullName }
  }
  throw "dumpbin.exe not found. Install VS Build Tools (C++ workload) or pass -DumpbinPath."
}

$dumpbin = Find-Dumpbin $DumpbinPath
Write-Host "dumpbin: $dumpbin"

$targets = @()
if (Test-Path $Path -PathType Container) {
  $targets = Get-ChildItem -Path $Path -Include *.exe,*.dll -Recurse -File
} else {
  $targets = Get-Item $Path
}
if (-not $targets -or $targets.Count -eq 0) { throw "No exe/dll found under: $Path" }

$failTotal = 0
foreach ($t in $targets) {
  $out = & $dumpbin //imports $t.FullName 2>$null
  $text = $out -join "`n"
  $dlls = [regex]::Matches($text, "[A-Za-z0-9_\-]+\.dll") |
          ForEach-Object { $_.Value.ToLower() } | Sort-Object -Unique
  $unknownDlls = @($dlls | Where-Object { $okDlls -notcontains $_ })
  $hits = [regex]::Matches($text, "(?i)\b($blRegex)\b") |
          ForEach-Object { $_.Value } | Sort-Object -Unique

  if ($hits.Count -gt 0) {
    $failTotal++
    Write-Host ("[FAIL] {0}" -f $t.Name) -ForegroundColor Red
    Write-Host ("   Win8+ imports: {0}" -f ($hits -join ", ")) -ForegroundColor Red
    if ($unknownDlls.Count -gt 0) {
      Write-Host ("   Unrecognized DLL imports (review): {0}" -f ($unknownDlls -join ", ")) -ForegroundColor Yellow
    }
  } else {
    $color = "Green"
    $note = ""
    if ($unknownDlls.Count -gt 0) { $color = "Yellow"; $note = " (unknown DLLs: " + ($unknownDlls -join ", ") + " - review manually)" }
    Write-Host ("[PASS] {0}{1}" -f $t.Name, $note) -ForegroundColor $color
  }
}

if ($failTotal -gt 0) {
  Write-Host "`nRESULT: FAIL - $failTotal file(s) import Win8+ APIs; they will NOT start on Windows 7." -ForegroundColor Red
  exit 1
} else {
  Write-Host "`nRESULT: PASS - no Win8+ API imports detected." -ForegroundColor Green
  exit 0
}
