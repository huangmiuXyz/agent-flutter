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
		flutter run $(FLUTTER_MODE) -d macos; \
		CONFIGURATION=$(if $(r),Release,Debug) FLUTTER_APP=build/macos/Build/Products/$(if $(r),Release,Debug)/agent.app \
			tools/deploy_code_forge.sh
		# reopen to pick up the framework
		open build/macos/Build/Products/$(if $(r),Release,Debug)/agent.app
else ifneq ($(IS_WINDOWS),)
		flutter run $(FLUTTER_MODE) -d windows
else
		flutter run $(FLUTTER_MODE)
endif

# macOS: 编译 code_forge 的 Rust 库并打包 framework
_build_code_forge:
ifeq ($(UNAME_S),Darwin)
	cd ~/.pub-cache/hosted/pub.dev/code_forge-10.8.0/rust && cargo build --release
	$(eval CODE_FORGE_DYLIB := $(HOME)/.pub-cache/hosted/pub.dev/code_forge-10.8.0/rust/target/release/libcode_forge.dylib)
	$(eval APP_FRAMEWORKS := build/macos/Build/Products/$(if $(r),Release,Debug)/agent.app/Contents/Frameworks)
	mkdir -p $(APP_FRAMEWORKS)/code_forge.framework/Versions/A/Resources
	cp $(CODE_FORGE_DYLIB) $(APP_FRAMEWORKS)/code_forge.framework/Versions/A/code_forge
	cd $(APP_FRAMEWORKS)/code_forge.framework && ln -sfh Versions/A/code_forge code_forge && ln -sfh Versions/A Versions/Current && ln -sfh Versions/A/Resources Resources
	install_name_tool -id "@rpath/code_forge.framework/code_forge" $(APP_FRAMEWORKS)/code_forge.framework/Versions/A/code_forge
	@plist=$(APP_FRAMEWORKS)/code_forge.framework/Versions/A/Resources/Info.plist; \
	if [ ! -f $$plist ]; then \
		echo '<?xml version="1.0" encoding="UTF-8"?>' > $$plist; \
		echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $$plist; \
		echo '<plist version="1.0"><dict><key>CFBundleExecutable</key><string>code_forge</string><key>CFBundleIdentifier</key><string>com.code-forge.rust</string><key>CFBundleName</key><string>code_forge</string><key>CFBundlePackageType</key><string>FMWK</string><key>CFBundleShortVersionString</key><string>10.8.0</string><key>CFBundleVersion</key><string>10.8.0</string><key>MinimumOSVersion</key><string>10.15</string></dict></plist>' >> $$plist; \
	fi
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
