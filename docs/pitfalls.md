# Pitfalls: every trap we hit, with root causes

> All of these were hit and confirmed on real machines. Read this before debugging — most Win7 llama.cpp failures fall into one of these buckets.

## 1. Loader traps — Win8+ APIs (binary never starts)

Modern llama.cpp imports Windows-8+ only APIs. On Win7 the loader fails **before `main()`**, so you get a popup or a silent exit — no log, no stack trace.

| API | Where it came from (v0.5.0) | Why it breaks Win7 | Fix in our patch |
|:--|:--|:--|:--|
| `CreateFile2` | `vendor/cpp-httplib/httplib.cpp` (static file serving of llama-server) | Win8+ only | replace with `CreateFileW` (identical behavior here) |
| `CreateFileMappingFromApp` | same | Win8+ only | `CreateFileMappingW` with size 0,0 (= map whole file, read-only) |
| `MapViewOfFileFromApp` | same | Win8+ only | `MapViewOfFile` with size 0 |
| `SetThreadInformation` (`ThreadPowerThrottling`) | `ggml/src/ggml-cpu/ggml-cpu.c` — inside a `#if _WIN32_WINNT >= 0x0602` gate that **defeats itself** when the SDK defaults to 0x0A00 | kernel32 has no such export on Win7 → loader error popup at process start | `GetProcAddress` runtime probe + global `_WIN32_WINNT=0x0601` (compiles the branch out) |
| upstream `#error` in `httplib.h` | rejects `_WIN32_WINNT < 0x0A00` at compile time | build-time, not runtime | neutralize (`#if 0`) once the three calls above are patched |
| `PrefetchVirtualMemory` | `src/llama-mmap.cpp` | Win8+ only — but upstream already probes it via `GetProcAddress` at runtime | none needed |

**The audit gate.** Source greps are necessary but not sufficient — the binary is the truth. `dumpbin /imports` (or the bundled [`audit/import-audit.ps1`](../audit/import-audit.ps1)) against a blacklist of 20+ Win8+ symbols:

```
SetThreadInformation, SetThreadDescription, GetThreadDescription, GetSystemTimePreciseAsFileTime,
WaitOnAddress, WakeByAddress*, SetDefaultDllDirectories, CreateFile2, CreateFileMapping2, *FromApp,
PrefetchVirtualMemory, MapViewOfFile3, VirtualAlloc2, GetOverlappedResultEx, PathCch*, AppPolicy*,
GetCurrentThreadStackLimits, SetProcessMitigationPolicy, *CpuSets, GetDpiFor*, SetProcessDpiAwarenessContext,
AdjustWindowRectExForDpi, GetSystemMetricsForDpi, AreDpiAwarenessContextsEqual, EnableNonClientDpiSupport,
GetAwarenessFromDpi*
```

Acceptable final import set for the engine: `KERNEL32, SHELL32, ADVAPI32, WS2_32` (+ `cudart64_110/cublas64_11/cublasLt64_11` for the CUDA build, whose own imports are clean — they only need KERNEL32). **Lesson: our first audit only checked four symbols and missed `SetThreadInformation` — the popup only surfaced on a real Win7 machine. Audit with the full list, every build.**

## 2. Build traps (compiles fine, dies on the target)

### 2.1 Multi-DLL + static CRT = silent death

Default llama.cpp builds shared libs (`ggml.dll`, `llama.dll`, …) with `/MT` static CRT — every DLL carries its **own CRT heap**. Objects allocated in one DLL and freed in another cross heap boundaries; `llama-server` then exits **silently during model load** (no log line, no event-log entry, exit code 127-ish). This looks exactly like "broken binary" and costs hours.

**Fix:** `-DBUILD_SHARED_LIBS=OFF` → single static exe. Root cause never returns.

### 2.2 OpenMP dependency

`GGML_OPENMP=ON` (default) makes the CPU backend import `VCOMP140.DLL`. Any machine without the VC++ redist gets `STATUS_DLL_NOT_FOUND`. `-DGGML_OPENMP=OFF` unless you specifically want OpenMP.

### 2.3 `GGML_NATIVE` is a build-machine fingerprint

Defaults to ON: ggml compiles for the **build machine's** CPU features (AVX2/AVX512 etc.). Binaries then crash with illegal instructions on older target CPUs. Always `-DGGML_NATIVE=OFF` for cross-machine deployment.

### 2.4 `_WIN32_WINNT` defaults

See [build-recipe.md](build-recipe.md) rule #4 — the sneakiest one because the codebase *looks* guarded, but the guards are `#if` compile-time and the default SDK level is Win10.

### 2.5 CUDA toolset detection after a custom CUDA install

If CMake says `No CUDA toolset found` despite CUDA being installed (custom/GUI install on a build box without VS integration): copy `CUDA\v11.4\extras\visual_studio_integration\MSBuildExtensions\*` into `BuildTools\MSBuild\Microsoft\VC\v160\BuildCustomizations\` **and** write the registry value `HKLM\SOFTWARE\NVIDIA Corporation\GPU Computing Toolkit\CUDA\v11.4 → InstallDir = <CUDA root>\`.

### 2.6 MSYS2/Git-Bash path mangling

`-DCMAKE_C_FLAGS="/D_WIN32_WINNT=0x0601"` from Git Bash becomes a mangled path (leading `/D…` looks POSIX). Use the initial-cache file (`build/win7-cache.cmake`) — shell-independent.

## 3. Runtime traps (target machine)

### 3.1 "Half-dead" driver stack

Symptom cluster (all observed simultaneously): `nvidia-smi` → `Failed to initialize NVML: Not Found`; CUDA init → `unknown error`; NVIDIA Control Panel won't open; **yet** Device Manager says the GPU "is working properly", `sc query nvlddmkm` shows RUNNING, and `C:\Windows\System32\nvcuda.dll` exists. User-state services run, kernel driver loads, but every real driver↔hardware conversation fails — typical of a partially broken / image-cloned driver install.

Diagnosis knives: `nvidia-smi` (full path on Win7: `C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe` — it is **not** on PATH), `dir C:\Windows\System32\nvcuda.dll`, `sc query nvlddmkm`, Device Manager driver **date** (a "clean install" that never launched its wizard leaves the old date untouched).

Fix: full custom → clean installation of 472.12/473.62. After a successful clean install, `nvidia-smi` prints the table and CUDA init succeeds.

### 3.2 Driver version traps

- NVIDIA dual numbering: driver `30.0.14.7212` (Device Manager) = marketing version **472.12**. R470 branch is the last line for Win7.
- **474.44 is Kepler-only** (GeForce 600 series) despite appearing in Win7/8 driver lists — it will not serve RTX 30xx.
- Display output on the discrete card is optional: iGPU for the desktop + discrete GPU as pure compute works perfectly (verify compute via `nvidia-smi` process table, not idle GPU-Util which is 0% when nobody is chatting).

### 3.3 Known upstream issue: long-context OOM on Win7 ([llama.cpp#22075](https://github.com/ggml-org/llama.cpp/issues/22075))

Same setup as ours (Win7 SP1 + RTX 3060 + CUDA 11.4): prompts around ~20k tokens make CUDA legacy-pool memory climb stepwise during prefill until OOM — the pool never returns memory on Win7. Mitigations: keep prompts under ~16K tokens, `-ub 512 -b 2048` (smaller transient allocations), restart the server to release. A `purge_pools` patch exists in the issue discussion if you need 20k+ prompts.

### 3.4 Small but annoying

- Model switch → 30-60 s load; HTTP 503 `Loading model` meanwhile — clients should wait for `listening` in the log.
- Port 8080 held by a previous instance → `--port 8081` (and update the client).

## 4. Ecosystem notes (as of 2026-09)

- **VS Code 1.70.2** is the last version running on Win7 (1.70.3 was pulled from the official update server; 1.71+ requires Win10). Direct archive: `https://update.code.visualstudio.com/1.70.2/win32-x64-archive/stable`
- **Firefox ESR 115** line is the last Firefox supporting Win7.
- Other projects, for comparison: [cloudwithax/llama-cpp-win7](https://github.com/cloudwithax/llama-cpp-win7) ships CPU-only builds; [KoboldCpp](https://github.com/LostRuins/koboldcpp) maintains Win7 support but recommends its no-CUDA build on Win7. To our knowledge this repo is the only **source-level CUDA (sm_86) Win7** recipe with an audit checklist.
- Network note: NVIDIA's download CDN geo-blocks some regions/IP ranges (403 on direct links); the official driver search page or a TechPowerUp archive (with published SHA256) are reliable fallbacks — always verify hashes.
