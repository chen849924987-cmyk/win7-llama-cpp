# NOTICE

## Scope of this repository

This repository contains **original documentation, scripts, and configuration** written for building and deploying [llama.cpp](https://github.com/ggml-org/llama.cpp) on Windows 7, plus one small patch file applied to llama.cpp source at build time. It does **not** redistribute llama.cpp, model weights, NVIDIA software, or any other third-party binary.

## Third-party components (used, not included)

- **llama.cpp** (ggml-org) — MIT License. The patch `patches/win7-compat.patch` modifies three files of the v0.5.0 source tree and is offered under the same MIT terms.
- **NVIDIA CUDA Toolkit runtime DLLs** (`cudart64_110.dll`, `cublas64_11.dll`, `cublasLt64_11.dll`) — proprietary NVIDIA software; obtain them from the official CUDA Toolkit installer and distribute per the NVIDIA CUDA Toolkit EULA (they are designated redistributable components). This repository only documents where to find them.
- **NVIDIA GeForce drivers** — proprietary; download from NVIDIA official channels. NVIDIA, GeForce, CUDA are trademarks of NVIDIA Corporation.
- **Model weights** (e.g. Qwen2.5-Coder) — download from their official Hugging Face repositories; each model carries its own license (Qwen2.5-Coder is Apache-2.0 at the time of writing — verify on the model page).
- **Microsoft Visual Studio / Windows SDK / Windows 7** — subject to Microsoft license terms.
- **win7-agent** (referenced in the guides as a third-party client) — see its own repository: https://github.com/Be-Young/win7-agent

## Trademarks

Windows, Visual Studio are trademarks of Microsoft Corporation. NVIDIA, CUDA, GeForce are trademarks of NVIDIA Corporation. All other trademarks belong to their respective owners.
