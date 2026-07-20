.PHONY: run build watch clean codegen

MSVC = cmd //c "tools\\msvc_cmd.bat"

# 全部重新生成（FRB + build_runner + 编译 Rust）+ 启动 app
run:
	$(MSVC) flutter_rust_bridge_codegen generate
	dart run build_runner build --delete-conflicting-outputs
	$(MSVC) cargo build --release -p rust_lib_agent
	cp ../agent-flutter-cli/target/release/rust_lib_agent.dll build/windows/x64/runner/Debug/
	flutter run

# flutter_rust_bridge 代码生成（单独执行）
codegen:
	$(MSVC) flutter_rust_bridge_codegen generate

# 仅重新生成 Dart 代码（freezed/riverpod 等）
build:
	dart run build_runner build --delete-conflicting-outputs

# 开发时后台监听（文件修改后自动重新生成）
watch:
	dart run build_runner watch --delete-conflicting-outputs

# 清理生成文件 + 缓存
clean:
	dart run build_runner clean
	find . -name "*.freezed.dart" -o -name "*.g.dart" -delete
