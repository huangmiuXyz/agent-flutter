@echo off
chcp 65001 >nul
title Agent Flutter - 环境初始化
echo ============================================
echo  Agent Flutter - 拉取最新代码后一键初始化
echo ============================================
echo.

:: ---- 1. 拉取最新代码 ----
echo [1/7] 拉取 Flutter 项目最新代码...
cd /d "%~dp0"
git pull
if %errorlevel% neq 0 (
    echo 拉取失败，请检查网络或手动处理冲突
    pause
    exit /b 1
)
echo OK
echo.

echo [2/7] 拉取 Rust CLI 项目最新代码...
cd /d "%~dp0..\agent-flutter-cli"
git pull
if %errorlevel% neq 0 (
    echo 拉取失败，请检查网络或手动处理冲突
    pause
    exit /b 1
)
echo OK
echo.

:: ---- 2. 设置 MSVC 编译环境 ----
echo [3/7] 设置 MSVC 编译环境...
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64
if %errorlevel% neq 0 (
    echo MSVC 环境初始化失败，请确认已安装 Visual Studio Build Tools 2022
    pause
    exit /b 1
)
echo OK
echo.

:: ---- 3. FRB 代码生成 ----
echo [4/7] 生成 flutter_rust_bridge 绑定代码...
cd /d "%~dp0"
flutter_rust_bridge_codegen generate
if %errorlevel% neq 0 (
    echo FRB 代码生成失败
    pause
    exit /b 1
)
echo OK
echo.

:: ---- 4. build_runner ----
echo [5/7] 运行 build_runner 生成 freezed/riverpod 代码...
dart run build_runner build --delete-conflicting-outputs
if %errorlevel% neq 0 (
    echo build_runner 失败
    pause
    exit /b 1
)
echo OK
echo.

:: ---- 5. 编译 Rust DLL ----
echo [6/7] 编译 Rust 动态库 (rust_lib_agent.dll)...
cd /d "%~dp0..\agent-flutter-cli"
cargo build --release -p rust_lib_agent
if %errorlevel% neq 0 (
    echo Rust 编译失败
    pause
    exit /b 1
)
echo OK
echo.

:: ---- 6. 复制 DLL 到 Flutter 构建目录 ----
echo [7/7] 复制 DLL 到 Flutter 输出目录...
copy /Y "target\release\rust_lib_agent.dll" "%~dp0build\windows\x64\runner\Debug\" >nul
echo OK
echo.

:: ---- 完成 ----
echo ============================================
echo  初始化完成！正在启动 Flutter 应用...
echo ============================================
cd /d "%~dp0"
flutter run -d windows

pause
