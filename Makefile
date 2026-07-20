.PHONY: run build watch clean patch codegen

# flutter_rust_bridge 代码生成（修改 Rust API 后需要运行）
codegen:
	flutter_rust_bridge_codegen generate

# 全部重新生成（FRB + build_runner）+ 启动 app
run:
	flutter_rust_bridge_codegen generate
	dart run build_runner build --delete-conflicting-outputs
	flutter run


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
