@echo off
chcp 65001 >nul

:: 设置 MSVC 环境并编译 Rust
call "%~dp0run_in_msvc_env.bat" cargo build --release --manifest-path %1 -p rust_lib_agent
if %errorlevel% neq 0 (
    exit /b 1
)

exit /b 0
