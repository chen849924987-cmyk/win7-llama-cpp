# win7-llama-cpp

[中文说明](README.zh-CN.md)

**Run [llama.cpp](https://github.com/ggml-org/llama.cpp) with CUDA acceleration on Windows 7** — source patches, build recipe, import-table audit checklist, and an offline deployment guide. Everything is verified end-to-end on a real machine (Windows 7 SP1 x64 + GeForce RTX 3060 12GB, generation speed ~60 tok/s on 7B / ~25-35 tok/s on 14B).

> Modern llama.cpp binaries crash on startup on Windows 7 because they import Win8+ APIs (`CreateFile2`, `CreateFileMappingFromApp`, `MapViewOfFileFromApp`, `SetThreadInformation`, …). This repo fixes those at **source level**, ships the exact **build recipe**, and documents every pitfall we hit along the way.

## Who needs this

- Air-gapped / offline machines locked to Windows 7 (industrial PCs, lab benches, legacy enterprise boxes)
- Any Win7 box with a discrete NVIDIA GPU from the RTX 20/30 era you want to use as an inference card (the GPU does not need display output — iGPU can drive the desktop)
- Anyone who tried official llama.cpp binaries on Win7 and hit *"The procedure entry point X could not be located in KERNEL32.dll"* or `ggml_cuda_init: failed to initialize CUDA`

## What's inside

| Path | Content |
|:--|:--|
| [`patches/win7-compat.patch`](patches/win7-compat.patch) | 3-file source patch against **llama.cpp v0.5.0** |
| [`build/`](build/) | CMake initial-cache (injects `_WIN32_WINNT=0x0601`) + ready-to-run build scripts (CUDA / CPU) |
| [`audit/import-audit.ps1`](audit/import-audit.ps1) | One-click PE import audit against a 20+ symbol Win8+ API blacklist — the gate that decides "will it start on Win7" |
| [`client/chat.html`](client/chat.html) | Zero-dependency chat page (works even in IE11) as a fallback client |
| [`docs/build-recipe.md`](docs/build-recipe.md) | Full build recipe (toolchain versions, cmake invocation, why every flag) |
| [`docs/deployment-guide.md`](docs/deployment-guide.md) | Offline deployment guide: driver → engine → model → smoke test → daily use |
| [`docs/pitfalls.md`](docs/pitfalls.md) | Every pitfall we hit, with root causes: silent multi-DLL heap crash, VCOMP140 dependency, `_WIN32_WINNT` default trap, driver half-dead diagnosis tree, long-context OOM (#22075) |
| [`docs/download-links.md`](docs/download-links.md) | Official download links + SHA256 for models, drivers, toolchain |

## Quick start (30 seconds version)

1. Get [llama.cpp v0.5.0 source](https://github.com/ggml-org/llama.cpp/archive/refs/tags/v0.5.0.zip), apply `patches/win7-compat.patch`
2. Build on a Win10/11 machine with VS2019 Build Tools (v142) + CUDA 11.4.3, using `build/build-cuda.bat` (recipe: [docs/build-recipe.md](docs/build-recipe.md))
3. Target Win7 machine: install the last Win7 GeForce driver (**472.12** or **473.62**; do *not* use 474.44 — Kepler-only)
4. Copy `llama-server.exe` + 3 CUDA runtime DLLs + your `.gguf` model to the target machine
5. Start: `llama-server.exe -m model.gguf -ngl 99 -c 16384 -fa on --host 127.0.0.1 --port 8080`

Full guide: [docs/deployment-guide.md](docs/deployment-guide.md)

## The four iron rules (TL;DR of the whole repo)

| Flag | Without it (measured failure) |
|:--|:--|
| `-DBUILD_SHARED_LIBS=OFF` | Default multi-DLL build + static CRT → each DLL owns a heap → llama-server **dies silently** while loading the model, no error at all |
| `-DGGML_OPENMP=OFF` | Runtime dependency on `VCOMP140.DLL` → `STATUS_DLL_NOT_FOUND` on machines without VC++ redist |
| `-DGGML_NATIVE=OFF` | Code compiled for the **build machine's** CPU (AVX2/AVX512) → illegal-instruction crash on older target CPUs |
| `_WIN32_WINNT=0x0601` globally | New SDKs default to Win10 → all `#if _WIN32_WINNT` gates in the codebase are defeated → `SetThreadInformation` import → loader error popup on Win7 |

More in [docs/pitfalls.md](docs/pitfalls.md).

## Verified setup

| Item | Value |
|:--|:--|
| OS | Windows 7 SP1 x64 |
| GPU | GeForce RTX 3060 12GB (display via iGPU; card used as pure compute) |
| Driver | 472.12 WHQL (30.0.14.7212) |
| Toolchain (build machine) | VS2019 Build Tools v142 (MSVC 14.29.30133) + CUDA 11.4.3 + CMake 3.20 |
| Models | Qwen2.5-Coder 7B / 14B Instruct Q4_K_M (GGUF, community quant by bartowski) |
| Measured | 7B: ~60 tok/s, 6.1GB VRAM · 14B: ~25-35 tok/s, ~11.3GB VRAM @ 16K context (KV q8_0) |

## Client integration

`llama-server` exposes an OpenAI-compatible API at `http://127.0.0.1:8080/v1` — any client that accepts a custom OpenAI base URL works. A built-in WebUI is served at the root path. [`client/chat.html`](client/chat.html) is a no-install fallback. For a full VS Code agent experience on Win7, see the community project [win7-agent](https://github.com/Be-Young/win7-agent).

## Scope & license

- This repo's original content: MIT — see [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md)
- Model weights are **not** redistributed; download from the linked official repos
- CUDA runtime DLLs are **not** redistributed; grab them from the official CUDA toolkit installer

## Roadmap

- GitHub Actions workflow that auto-builds Win7-compatible binaries per upstream tag
- Upstream contributions: Win7 build docs for llama.cpp; `.cs` file-type support for win7-agent
