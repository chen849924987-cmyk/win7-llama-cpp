# Download links & checksums

> All links verified 2026-09. Nothing in this repo redistributes third-party binaries or weights — everything comes from the official sources below. Verify SHA256 (`certutil -hashfile <file> SHA256`) after download.

## Models (Qwen2.5-Coder Instruct, Q4_K_M GGUF)

Community quant by **bartowski** (same weights as the official release, GGUF conversion):

| File | Size | Link (append `?download=true`) | SHA256 |
|:--|:--|:--|:--|
| Qwen2.5-Coder-14B-Instruct-Q4_K_M.gguf | 8,988,111,072 | `https://huggingface.co/bartowski/Qwen2.5-Coder-14B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-14B-Instruct-Q4_K_M.gguf` | `2946d28c9e1bb2bcae6d42e8678863a31775df6f740315c7d7e6d6b6411f5937` |
| Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf | 4,683,074,336 | `https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf` | `1664fccab734674a50763490a8c6931b70e3f2f8ec10031b54806d30e5f956b6` |

Mirror for slow HF routes: replace the domain with `hf-mirror.com`.

## llama.cpp source

| Item | Link |
|:--|:--|
| v0.5.0 zip | `https://github.com/ggml-org/llama.cpp/archive/refs/tags/v0.5.0.zip` |

## Toolchain (build machine only)

| Tool | Link |
|:--|:--|
| VS 2019 Build Tools (v142 / MSVC 14.29) | `https://aka.ms/vs/16/release/vs_BuildTools.exe` (select the C++ workload) |
| CUDA Toolkit 11.4.3 | `https://developer.download.nvidia.com/compute/cuda/11.4.3/local_installers/cuda_11.4.3_472.50_win10.exe` (≈3.0 GB; name says win10, runs on Win10/11 build hosts and produces Win7-compatible binaries) |
| CMake | bundled with VS Build Tools, or `https://cmake.org/download/` |

## NVIDIA drivers (target machine, Win7 x64)

Official direct pattern (geo-blocking may apply in some regions — the [official driver search](https://www.nvidia.com/en-us/drivers/) page always works):

| Version | Link | Note |
|:--|:--|:--|
| 472.12 WHQL | `https://us.download.nvidia.com/Windows/472.12/472.12-desktop-win8-win7-64bit-international-whql.exe` (608 MB) | last Game Ready driver for Win7/8/8.1; SHA256 `A4B182D13D3DE60C5ED4BBD59122345C9BDE159F95B3E92C2954EA4E83C13740` (cross-checkable on TechPowerUp's archive) |
| 473.62 WHQL | `https://us.download.nvidia.com/Windows/473.62/473.62-desktop-win8-win7-64bit-international-whql.exe` (593 MB) | 2022-05 refresh, clean-install fallback |

⚠ **474.44 is Kepler-only** (GeForce 600 series) — it appears in Win7/8 lists but does not serve RTX 30xx.

## Support tools (optional)

| Tool | Link | Note |
|:--|:--|:--|
| VC++ 2015-2022 x64 redist | `https://aka.ms/vs/17/release/vc_redist.x64.exe` | only needed by third-party clients; our engine is static |
| Firefox ESR 115 (last Win7 line) | `https://download-installer.cdn.mozilla.net/pub/firefox/releases/115.36.0esr/win64/zh-CN/Firefox%20Setup%20115.36.0esr.exe` (pick your language; 115.x pattern) | for the built-in WebUI on the target machine |
| VS Code 1.70.2 portable (last Win7 version) | `https://update.code.visualstudio.com/1.70.2/win32-x64-archive/stable` | never update it in-place (1.71+ drops Win7) |
| 7-Zip 21.07 (Win7-compatible) | `https://www.7-zip.org/a/7z2107-x64.exe` | only if you need to unpack `.7z` assets |
