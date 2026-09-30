@echo off
rem ============================================================
rem Build llama.cpp (CPU-only baseline, Win7-compatible)
rem Edit 2 vars below. GGML_NATIVE=OFF keeps baseline x86-64.
rem ============================================================
setlocal

rem -- EDIT THESE --
set "CMAKE=C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
set "SRC=%~dp0..\..\llama.cpp-0.5.0"
rem ----------------

if not exist "%CMAKE%" ( echo CMAKE not found: "%CMAKE%" & exit /b 1 )
if not exist "%SRC%\CMakeLists.txt" ( echo llama.cpp source not found: "%SRC%" & exit /b 1 )
findstr /C:"pfn_set_thread_information" "%SRC%\ggml\src\ggml-cpu\ggml-cpu.c" >nul 2>&1
if errorlevel 1 ( echo [ERROR] Win7 patch not applied to "%SRC%" - see patches\win7-compat.patch & exit /b 1 )

set "BUILD=%~dp0build-cpu"

"%CMAKE%" -S "%SRC%" -B "%BUILD%" -C "%~dp0win7-cache.cmake" -G "Visual Studio 16 2019" -A x64 ^
  -DBUILD_SHARED_LIBS=OFF -DGGML_NATIVE=OFF -DGGML_OPENMP=OFF ^
  -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF ^
  -DLLAMA_BUILD_TOOLS=ON -DLLAMA_BUILD_SERVER=ON ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded || exit /b 1

"%CMAKE%" --build "%BUILD%" --config Release -j 8 --target llama-server llama-cli || exit /b 1

echo.
echo === DONE. Deployables: ===
dir /b "%BUILD%\bin\Release\*.exe"
echo Audit before shipping:
echo   powershell -File "%~dp0..\audit\import-audit.ps1" -Path "%BUILD%\bin\Release\llama-server.exe"
endlocal
