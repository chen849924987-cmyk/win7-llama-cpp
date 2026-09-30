# Offline deployment guide (Windows 7 target machine)

> Everything happens offline on the target machine. Build artifacts come from the [build recipe](build-recipe.md); model weights from the official links in [download-links.md](download-links.md).

## 0. Target machine requirements

- Windows 7 SP1 **x64**
- NVIDIA GPU with driver **≥ 472.12** (R470 branch — the last line supporting Win7)
- RAM ≥ 16 GB recommended; free disk ≥ 20 GB
- The GPU does **not** need display output: driving the desktop from the iGPU and using the discrete card as a pure compute device is a fully supported (and quiet) configuration

## 1. Graphics driver

1. Check the current driver first — Device Manager → Display adapters → Properties → Driver tab, or
   `"C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe"` (on Win7-era drivers this tool is **not** in PATH/System32)
2. Version ≥ 472.12 (e.g. 472.12 / 473.62) → skip installation
3. Otherwise install **472.12** or **473.62** (see [download-links.md](download-links.md)); choose *Custom → perform a clean installation*
4. ⚠ Do **not** install 474.44 — despite its name suggesting Win7/8, that branch is Kepler-only and will not serve an RTX 30xx card

Driver trouble-shooting tree (measured): if `nvidia-smi` says `Failed to initialize NVML: Not Found` while Device Manager claims the device "is working properly", and NVIDIA Control Panel won't open, and CUDA init fails with `unknown error` → the driver stack is half-dead (files present, kernel state broken, often from an image-cloned install). Fix: clean reinstall of 472.12/473.62. Diagnostic knives that worked: `sc query nvlddmkm` (kernel driver state), checking that `C:\Windows\System32\nvcuda.dll` exists.

## 2. Copy the runtime package

```
engine\        llama-server.exe, llama-cli.exe, cudart64_110.dll, cublas64_11.dll, cublasLt64_11.dll
models\        qwen2.5-coder-7b-instruct-q4_k_m.gguf (4.7 GB), qwen2.5-coder-14b-... (9.0 GB)
client\        chat.html (optional fallback)
```

Use a plain-ASCII target path (e.g. `D:\llm\`). Verify file integrity against the hashes in [download-links.md](download-links.md) (`certutil -hashfile <file> SHA256`).

## 3. First smoke test (7B)

```bat
engine\llama-server.exe -m models\qwen2.5-coder-7b-instruct-q4_k_m.gguf ^
  --alias qwen2.5-coder-7b -ngl 99 -c 8192 -fa on -t 8 ^
  --host 127.0.0.1 --port 8080
```

Wait for `listening on http://127.0.0.1:8080`, then verify all three:

1. Open `http://127.0.0.1:8080` in any browser → chat works
2. `nvidia-smi` → process table shows `llama-server.exe` holding ~6 GB (idle GPU-Util shows 0% — that is normal; utilization only moves during inference)
3. Server log shows `offloaded 28/28 layers` and no red `ggml_cuda_init: failed` line

Generation speed sanity check: 7B on RTX 3060 ≈ 55-70 tok/s (text visibly streaming); if you see 3-6 tok/s the model is on the CPU — go back to step 1.

## 4. Daily driver (14B, 16K context)

```bat
engine\llama-server.exe -m models\qwen2.5-coder-14b-instruct-q4_k_m.gguf ^
  --alias qwen2.5-coder-14b -ngl 99 -c 16384 -ctk q8_0 -ctv q8_0 ^
  -fa on -b 2048 -ub 512 --parallel 1 -t 8 --host 127.0.0.1 --port 8080
```

Why these flags: KV cache quantized to q8_0 halves its footprint (~96 KiB/token) so 16K context fits in 12 GB (~11.3 GB total with weights + compute buffer); `-ub 512 -b 2048` shrinks the compute buffer and mitigates upstream issue [#22075](https://github.com/ggml-org/llama.cpp/issues/22075) (Win7 CUDA legacy-pool accumulation on long prompts); `--parallel 1` gives the whole window to one session. Generation speed is memory-bandwidth bound (~25-35 tok/s) and unaffected. Expect a 30-60 s load time after switching models; requests during load return HTTP 503 `Loading model` — not an error.

## 5. Clients

- Built-in WebUI: browser → `http://127.0.0.1:8080`
- Any OpenAI-compatible client: base URL `http://127.0.0.1:8080/v1`
- Fallback: `client/chat.html` (zero dependency, runs even in IE11; requests go directly to `/v1/chat/completions`)
- Full VS Code agent experience on Win7: community project [win7-agent](https://github.com/Be-Young/win7-agent) (VS Code 1.70.x + OpenAI-compatible endpoint)

## 6. API quick reference

| Endpoint | Purpose |
|:--|:--|
| `POST /v1/chat/completions` | chat (OpenAI-compatible) |
| `GET /v1/models` | model list |
| `GET /health` | readiness (503 while loading) |
| `/` (root) | WebUI |

## 7. Troubleshooting table

| Symptom | Cause | Fix |
|:--|:--|:--|
| Popup: *procedure entry point SetThreadInformation / CreateFile2 … could not be located in KERNEL32.dll* | Binary not built with the Win7 patch / `_WIN32_WINNT` not set | Rebuild per [build-recipe.md](build-recipe.md); verify with [import-audit.ps1](../audit/import-audit.ps1) |
| Missing `cublas64_11.dll` / `cudart64_110.dll` | Engine folder incomplete or antivirus quarantined DLLs | Restore per SHA256 list; whitelist the folder |
| Popup mentioning `VCOMP140.DLL` | Build used OpenMP | Rebuild with `-DGGML_OPENMP=OFF` |
| `ggml_cuda_init: failed to initialize CUDA: unknown error` + server falls back to CPU | Driver stack half-dead (see §1 tree) | Clean-reinstall 472.12/473.62; verify with `nvidia-smi` |
| `nvidia-smi` not recognized | Win7 drivers don't add it to PATH | Full path: `"C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe"` |
| HTTP 503 `Loading model` | Model still loading after a switch (30-60 s for 14B) | Wait for `listening` in the log, then retry |
| `CUDA error: out of memory` during very long prompts | Upstream [#22075](https://github.com/ggml-org/llama.cpp/issues/22075): Win7 CUDA legacy pool never returns memory; ~20k-token prompts accumulate | Stay under ~16K prompt size; `-ub 512 -b 2048` helps; restart the server to release |
| Port busy (`Address already in use`) | Another instance on 8080 | `--port 8081`, update client config |
| Very slow generation (~4 tok/s) | Model fell back to CPU | Check step 3 verification; fix driver, confirm `offloaded N/N layers` in log |
