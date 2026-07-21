@echo off
chcp 65001 >nul

:: 设置 MSVC 编译环境
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64
if %errorlevel% neq 0 (
    echo MSVC 环境初始化失败，请确认已安装 Visual Studio Build Tools 2022
    exit /b 1
)

:: 执行传入的命令
%*
if %errorlevel% neq 0 (
    exit /b 1
)

exit /b 0
