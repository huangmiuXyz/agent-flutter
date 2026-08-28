.PHONY: run codegen apk patch-cargokit

CLI_MANIFEST = ../agent-flutter-cli/Cargo.toml
CLI_DIR = ../agent-flutter-cli

# Detect OS (uname returns MINGW64_NT/MSYS_NT on Git Bash; Windows_NT on real Windows)
UNAME_S := $(shell uname -s)
IS_WINDOWS := $(findstring NT,$(UNAME_S))

# Flutter run 模式：make run → debug；make run r=1 → --release（预备发布）
FLUTTER_MODE = $(if $(r),--release,--debug)

# ── Android 构建环境（均可用外部环境变量覆盖：make apk ANDROID_HOME=/path/to/sdk）──
# flutter 工具只认环境变量，不读 android/local.properties 里的 sdk.dir
ANDROID_HOME ?= /opt/homebrew/share/android-commandlinetools
# AGP 9.0.1 + Gradle 9.1 要求 JDK 17+；brew 的 openjdk 是 keg-only，
# /usr/libexec/java_home 枚举不到，只能直接指向 opt 目录
ifeq ($(strip $(JAVA_HOME)),)
JAVA_HOME := $(firstword $(wildcard \
	/opt/homebrew/opt/openjdk@21 /opt/homebrew/opt/openjdk@17))
endif
# aws-lc-sys 的 C 构建走 SDK 自带 cmake，默认不在 PATH 上
ANDROID_CMAKE := $(ANDROID_HOME)/cmake/3.22.1/bin

APK_ENV = ANDROID_HOME=$(ANDROID_HOME) ANDROID_SDK_ROOT=$(ANDROID_HOME) \
	JAVA_HOME=$(JAVA_HOME) PATH="$(ANDROID_CMAKE):$$PATH"

# 本机 rustup 只装了 aarch64-linux-android，故固定 android-arm64；
# 要出多 ABI 先补 target：
#   rustup target add armv7-linux-androideabi i686-linux-android x86_64-linux-android
# 并去掉 --target-platform（release 签名仍是 debug key，见 android/app/build.gradle.kts）
apk: patch-cargokit
	$(APK_ENV) flutter build apk $(FLUTTER_MODE) --target-platform android-arm64
	@echo "APK: build/app/outputs/flutter-apk/app-$(if $(r),release,debug).apk"

# cargokit 生成的 rust_builder 被 .gitignore 忽略，重新 integrate 后会带回
# Gradle 9 不兼容的 project.exec 与过旧的 SDK 版本，构建前重新打补丁
patch-cargokit:
	@bash tools/patch_cargokit.sh

# 全部重新生成（FRB codegen + 编译 Rust）+ 启动 app
run:
ifneq ($(IS_WINDOWS),)
		MSYS2_ARG_CONV_EXCL='*' cmd.exe /c "tools\run_in_msvc_env.bat flutter_rust_bridge_codegen generate"
else
		flutter_rust_bridge_codegen generate
endif
ifneq ($(IS_WINDOWS),)
		MSYS2_ARG_CONV_EXCL='*' cmd.exe /c "tools\run_in_msvc_env.bat cargo sweep -m 3GB $(CLI_DIR)"
		MSYS2_ARG_CONV_EXCL='*' cmd.exe /c "tools\run_in_msvc_env.bat cargo build --release --manifest-path $(CLI_MANIFEST) -p rust_lib_agent"
		cp $(CLI_DIR)/target/release/rust_lib_agent.dll build/windows/x64/runner/Debug/
else
		cd $(CLI_DIR) && cargo sweep -m 3GB
		cargo build --release --manifest-path $(CLI_MANIFEST) -p rust_lib_agent
endif
ifeq ($(UNAME_S),Darwin)
		flutter build macos $(FLUTTER_MODE)
		CONFIGURATION=$(if $(r),Release,Debug) FLUTTER_APP=build/macos/Build/Products/$(if $(r),Release,Debug)/agent.app \
			tools/deploy_code_forge.sh
		flutter run $(FLUTTER_MODE) -d macos
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
	cd $(APP_FRAMEWORKS)/code_forge.framework && ln -sfh Versions/A/code_forge code_forge && ln -sfh A Versions/Current && ln -sfh Versions/A/Resources Resources
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
