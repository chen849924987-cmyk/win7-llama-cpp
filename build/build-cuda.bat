@echo off
rem ============================================================
rem Build llama.cpp (CUDA, Win7-compatible) - edit 4 vars below
rem Produces: build-cuda\bin\Release\llama-server.exe / llama-cli.exe
rem Then audit the exe:  powershell -File ..\audit\import-audit.ps1 -Path <exe>
rem ============================================================
setlocal

rem -- EDIT THESE --
set "CMAKE=C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
set "CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.4"
set "SRC=%~dp0..\..\llama.cpp-0.5.0"
set "ARCH=86"
rem ----------------

if not exist "%CMAKE%" ( echo CMAKE not found: "%CMAKE%" & exit /b 1 )
if not exist "%CUDA_PATH%\bin\nvcc.exe" ( echo CUDA not found: "%CUDA_PATH%" & exit /b 1 )
if not exist "%SRC%\CMakeLists.txt" ( echo llama.cpp source not found: "%SRC%" & exit /b 1 )
rem Verify the Win7 patch is applied (runtime-probe marker in ggml-cpu.c)
findstr /C:"pfn_set_thread_information" "%SRC%\ggml\src\ggml-cpu\ggml-cpu.c" >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Win7 patch not applied to "%SRC%" - see patches\win7-compat.patch
  exit /b 1
)

set "PATH=%CUDA_PATH%\bin;%PATH%"
set "BUILD=%~dp0build-cuda"

"%CMAKE%" -S "%SRC%" -B "%BUILD%" -C "%~dp0win7-cache.cmake" -G "Visual Studio 16 2019" -A x64 ^
  -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=%ARCH% ^
  -DBUILD_SHARED_LIBS=OFF -DGGML_NATIVE=OFF -DGGML_OPENMP=OFF ^
  -DCUDAToolkit_ROOT="%CUDA_PATH%" ^
  -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF ^
  -DLLAMA_BUILD_TOOLS=ON -DLLAMA_BUILD_SERVER=ON ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded || exit /b 1

"%CMAKE%" --build "%BUILD%" --config Release -j 8 --target llama-server llama-cli || exit /b 1

echo.
echo === DONE. Deployables: ===
dir /b "%BUILD%\bin\Release\*.exe"
echo plus CUDA runtime DLLs from "%CUDA_PATH%\bin": cudart64_110.dll cublas64_11.dll cublasLt64_11.dll
echo Audit before shipping:
echo   powershell -File "%~dp0..\audit\import-audit.ps1" -Path "%BUILD%\bin\Release\llama-server.exe"
endlocal
