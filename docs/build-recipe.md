# Build recipe (reproducible)

> Everything below was executed and verified on a real build machine (Windows 10, VS2019 Build Tools, CUDA 11.4.3), producing binaries that run on Windows 7 SP1 x64.

## 1. Prerequisites

| Tool | Version | Note |
|:--|:--|:--|
| [Visual Studio 2019 Build Tools](https://visualstudio.microsoft.com/vs/older-downloads/) | v142 toolset, MSVC **14.29.x** (verify: `cl.exe` exists under `VC/Tools/MSVC/14.29.*/`) | CUDA 11.4 does not recognize newer MSVC versions without hacks — pin to 14.29 |
| [CUDA Toolkit 11.4.x](https://developer.nvidia.com/cuda-11-4-3-download-archive) | 11.4.3 tested (V11.4.152) | The **last CUDA release supporting Windows 7** as a target. Build on Win10/11; binaries run on Win7 |
| CMake | 3.20+ (the one bundled with VS Build Tools works) | needs `CMAKE_CUDA_ARCHITECTURES` support |
| llama.cpp source | tag **v0.5.0** ([zip](https://github.com/ggml-org/llama.cpp/archive/refs/tags/v0.5.0.zip)) | other tags need re-checking against the patch and the audit |

## 2. Apply the Win7-compat patch

```bat
cd llama.cpp-0.5.0
git apply win7-compat.patch
```

The patch touches exactly three files:

| File | Change |
|:--|:--|
| `vendor/cpp-httplib/httplib.cpp` | `CreateFile2` → `CreateFileW`; `CreateFileMappingFromApp` → `CreateFileMappingW` (0,0 = map whole file); `MapViewOfFileFromApp` → `MapViewOfFile` (size 0 = whole section) |
| `vendor/cpp-httplib/httplib.h` | neutralize the upstream `#error "cpp-httplib doesn't support Windows 8 or lower"` gate (`#if 0`) — legitimate here because the implementation above was made Win7-compatible |
| `ggml/src/ggml-cpu/ggml-cpu.c` | `SetThreadInformation(ThreadPowerThrottling)` call wrapped in a `GetProcAddress` runtime probe, so the loader never requires the Win8+ export |

Note: `PrefetchVirtualMemory` (used in `llama-mmap.cpp`) is **already** runtime-probed by upstream — no change needed. Before every release build, re-grep the source for Win8+ API usage and re-run the audit (see [`audit/import-audit.ps1`](../audit/import-audit.ps1)).

## 3. The four iron rules

| Flag | Without it (measured failure mode) |
|:--|:--|
| `-DBUILD_SHARED_LIBS=OFF` | Default multi-DLL build links static CRT into each DLL → cross-DLL object ownership → llama-server **exits silently during model load** (no error text, exit code 127 / 0xC0000135-class). Single-file static build removes the entire class of failure |
| `-DGGML_OPENMP=OFF` | `ggml-cpu` then depends on `VCOMP140.DLL` → `STATUS_DLL_NOT_FOUND` on any machine without the VC++ redist |
| `-DGGML_NATIVE=OFF` | Baseline x86-64 codegen instead of the **build machine's** instruction set (AVX2/AVX512) — prevents illegal-instruction crashes on older target CPUs |
| `_WIN32_WINNT=0x0601` (C/C++/CUDA) | Without it, recent Windows SDKs default to 0x0A00 (Win10) and every `#if _WIN32_WINNT` gate in the codebase compiles-in Win8+ code paths — this is what produced the `SetThreadInformation` loader popup on real Win7 |

## 4. Why the CMake "initial cache" trick

On Git Bash / MSYS2 shells, a command-line define like `-DCMAKE_C_FLAGS="/D_WIN32_WINNT=0x0601 ..."` gets **path-mangled** by MSYS argument conversion (the leading `/D` looks like a POSIX path). Passing flags through an initial cache file avoids the shell entirely:

```cmake
# win7-cache.cmake
set(CMAKE_C_FLAGS "/D_WIN32_WINNT=0x0601 /DWINVER=0x0601" CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS "/D_WIN32_WINNT=0x0601 /DWINVER=0x0601" CACHE STRING "" FORCE)
set(CMAKE_CUDA_FLAGS "/D_WIN32_WINNT=0x0601 /DWINVER=0x0601" CACHE STRING "" FORCE)
```

(If you build from cmd.exe or PowerShell you can pass the flags inline; the cache file works everywhere.)

## 5. Build commands (CUDA flavor, RTX 30xx = sm_86)

```bat
cmake -S llama.cpp-0.5.0 -B build-cuda -C win7-cache.cmake -G "Visual Studio 16 2019" -A x64 ^
  -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=86 ^
  -DBUILD_SHARED_LIBS=OFF -DGGML_NATIVE=OFF -DGGML_OPENMP=OFF ^
  -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF ^
  -DLLAMA_BUILD_TOOLS=ON -DLLAMA_BUILD_SERVER=ON ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded
cmake --build build-cuda --config Release -j 8 --target llama-server llama-cli
```

CPU flavor: same command minus `-DGGML_CUDA=ON`. (`/MT` static CRT via `CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded` — the target machine needs no VC++ redist for the engine itself.)

## 6. Deployable output

Copy from `build-cuda/bin/Release/`:

- `llama-server.exe`, `llama-cli.exe`
- CUDA 11.4 runtime DLLs (from the toolkit's `bin\`): `cudart64_110.dll`, `cublas64_11.dll`, `cublasLt64_11.dll` — or grab them from the installed toolkit on the target machine per NVIDIA's redistributable terms

## 7. Acceptance gate before shipping

```powershell
powershell -File audit\import-audit.ps1 -Path build-cuda\bin\Release\llama-server.exe
```

`PASS` (imports limited to KERNEL32/SHELL32/ADVAPI32/WS2_32/USER32-era exports + the three CUDA DLLs) is the hard prerequisite for Win7 startup. Also smoke-test the CPU flavor locally with a small model — a silent-exit there means a build-flag regression, not a target-machine problem.
