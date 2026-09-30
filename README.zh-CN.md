# win7-llama-cpp

**在 Windows 7 上以 CUDA 加速运行 [llama.cpp](https://github.com/ggml-org/llama.cpp)** —— 源码级补丁、编译配方、导入表审查清单、离线部署手册。全部内容在真实机器上端到端验证（Windows 7 SP1 x64 + GeForce RTX 3060 12GB：7B 生成约 60 token/s，14B 约 25-35 token/s）。

> 现代 llama.cpp 的预编译版在 Win7 上启动即崩，因为导入了 Win8+ 独有 API（`CreateFile2`、`CreateFileMappingFromApp`、`MapViewOfFileFromApp`、`SetThreadInformation`……）。本仓库在**源码级**修复这些调用，给出精确的**编译配方**，并把踩过的每一个坑写成文档。

## 适合谁

- 锁死 Win7、完全离线的机器（工业上位机、实验室旧机、企业存量设备）
- 带独显（RTX 20/30 代）的 Win7 机器，想把显卡当纯算力卡用（显卡**不需要**接显示器，核显亮屏即可）
- 在 Win7 上跑官方 llama.cpp 报「无法定位程序输入点 xxx 于 KERNEL32.dll」或 `ggml_cuda_init: failed to initialize CUDA` 的人

## 包内容

| 路径 | 内容 |
|:--|:--|
| [`patches/win7-compat.patch`](patches/win7-compat.patch) | 针对 llama.cpp **v0.5.0** 的三文件源码补丁 |
| [`build/`](build/) | CMake 初始缓存（注入 `_WIN32_WINNT=0x0601`）+ 双击即用的编译脚本（CUDA / CPU 版） |
| [`audit/import-audit.ps1`](audit/import-audit.ps1) | 一键 PE 导入表审查：对着 20+ 个 Win8+ API 黑名单扫——产物能否在 Win7 启动的判死闸口 |
| [`client/chat.html`](client/chat.html) | 零依赖聊天兜底页（IE11 都能跑） |
| [`docs/build-recipe.md`](docs/build-recipe.md) | 编译配方（工具链版本、cmake 调用、每个参数为什么必须） |
| [`docs/deployment-guide.md`](docs/deployment-guide.md) | 离线部署手册：驱动 → 引擎 → 模型 → 冒烟 → 日常使用 |
| [`docs/pitfalls.md`](docs/pitfalls.md) | 踩坑全录（带根因）：多 DLL 堆崩溃、VCOMP140 依赖、`_WIN32_WINNT` 默认值陷阱、驱动半残排障树、长上下文 OOM（#22075） |
| [`docs/download-links.md`](docs/download-links.md) | 模型/驱动/工具链官方直链 + SHA256 |

## 快速开始（30 秒版）

1. 取 [llama.cpp v0.5.0 源码](https://github.com/ggml-org/llama.cpp/archive/refs/tags/v0.5.0.zip)，打上 `patches/win7-compat.patch`
2. 在 Win10/11 编译机（VS2019 Build Tools v142 + CUDA 11.4.3）用 `build/build-cuda.bat` 编译（详见 [docs/build-recipe.md](docs/build-recipe.md)）
3. 目标 Win7 机装最后的 Win7 GeForce 驱动（**472.12** 或 **473.62**；别用 474.44——那是 Kepler 老卡专用分支）
4. 拷 `llama-server.exe` + 3 个 CUDA 运行库 DLL + `.gguf` 模型到目标机
5. 启动：`llama-server.exe -m model.gguf -ngl 99 -c 16384 -fa on --host 127.0.0.1 --port 8080`

完整手册：[docs/deployment-guide.md](docs/deployment-guide.md)

## 四条铁律（全仓库的 TL;DR）

| 参数 | 不加的后果（实测） |
|:--|:--|
| `-DBUILD_SHARED_LIBS=OFF` | 默认多 DLL + 静态 CRT → 各 DLL 自持堆 → llama-server **加载模型时无声暴毙**，零报错 |
| `-DGGML_OPENMP=OFF` | 运行期依赖 `VCOMP140.DLL` → 未装 VC++ 运行库的机器直接 STATUS_DLL_NOT_FOUND |
| `-DGGML_NATIVE=OFF` | 按**编译机** CPU 指令集生成代码 → 老 CPU 目标机非法指令崩溃 |
| 全局 `_WIN32_WINNT=0x0601` | 新 SDK 默认按 Win10 编 → 代码里所有 `#if _WIN32_WINNT` 版本门槛失效 → 导入 `SetThreadInformation` → Win7 加载即弹窗 |

更多见 [docs/pitfalls.md](docs/pitfalls.md)。

## 已验证环境

| 项 | 值 |
|:--|:--|
| 操作系统 | Windows 7 SP1 x64 |
| 显卡 | GeForce RTX 3060 12GB（核显输出显示，显卡纯算力） |
| 驱动 | 472.12 WHQL（30.0.14.7212） |
| 编译机工具链 | VS2019 Build Tools v142（MSVC 14.29.30133）+ CUDA 11.4.3 + CMake 3.20 |
| 模型 | Qwen2.5-Coder 7B / 14B Instruct Q4_K_M（GGUF，bartowski 社区量化） |
| 实测 | 7B：约 60 token/s、显存 6.1GB；14B：约 25-35 token/s、16K 上下文（KV q8_0）约 11.3GB |

## 客户端接入

`llama-server` 在 `http://127.0.0.1:8080/v1` 提供 OpenAI 兼容接口——任何支持自定义 OpenAI 地址的客户端都能接；根路径自带 WebUI；[`client/chat.html`](client/chat.html) 是免安装兜底页。要在 Win7 上获得完整的 VS Code Agent 体验，推荐社区项目 [win7-agent](https://github.com/Be-Young/win7-agent)。

## 范围与许可

- 本仓库原创内容：MIT（见 [LICENSE](LICENSE) 与 [NOTICE.md](NOTICE.md)）
- 模型权重**不随库分发**，请从链接的官方仓库下载
- CUDA 运行库 DLL **不随库分发**，请从官方 CUDA Toolkit 安装包获取
