.PHONY: run build watch clean codegen

CLI_MANIFEST = ../agent-flutter-cli/Cargo.toml
CLI_DIR = ../agent-flutter-cli

# Detect OS (uname returns MINGW64_NT/MSYS_NT on Git Bash; Windows_NT on real Windows)
UNAME_S := $(shell uname -s)
IS_WINDOWS := $(findstring NT,$(UNAME_S))

# Flutter run 模式：make run → debug；make run r=1 → --release（预备发布）
FLUTTER_MODE = $(if $(r),--release,)

# 全部重新生成（FRB + build_runner + 编译 Rust）+ 启动 app
run:
ifneq ($(IS_WINDOWS),)
		MSYS2_ARG_CONV_EXCL='*' cmd.exe /c "tools\run_in_msvc_env.bat flutter_rust_bridge_codegen generate"
else
		flutter_rust_bridge_codegen generate
endif
		dart run build_runner build --delete-conflicting-outputs
ifneq ($(IS_WINDOWS),)
		MSYS2_ARG_CONV_EXCL='*' cmd.exe /c "tools\run_in_msvc_env.bat cargo build --release --manifest-path $(CLI_MANIFEST) -p rust_lib_agent"
		cp $(CLI_DIR)/target/release/rust_lib_agent.dll build/windows/x64/runner/Debug/
else
		cargo build --release --manifest-path $(CLI_MANIFEST) -p rust_lib_agent
endif
ifeq ($(UNAME_S),Darwin)
		flutter run $(FLUTTER_MODE) -d macos
else ifneq ($(IS_WINDOWS),)
		flutter run $(FLUTTER_MODE) -d windows
else
		flutter run $(FLUTTER_MODE)
endif

# flutter_rust_bridge 代码生成（单独执行）
codegen:
ifneq ($(IS_WINDOWS),)
	MSYS2_ARG_CONV_EXCL='*' cmd.exe /c "tools\run_in_msvc_env.bat flutter_rust_bridge_codegen generate"
else
	flutter_rust_bridge_codegen generate
endif

# 仅重新生成 Dart 代码（freezed）
build:
	dart run build_runner build --delete-conflicting-outputs

# 开发时后台监听（文件修改后自动重新生成）
watch:
	dart run build_runner watch --delete-conflicting-outputs

# 清理生成文件 + 缓存
clean:
	dart run build_runner clean
	find . -name "*.freezed.dart" -delete
