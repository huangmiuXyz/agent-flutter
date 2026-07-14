.PHONY: run build watch clean patch

# 应用 patch + 生成代码 + 启动 app
run: patch
	dart run build_runner build
	flutter run

# 手动应用 patch（或 pub get 后自动执行）
patch:
	dart run patch/auto_patch.dart

# 仅重新生成代码
build:
	dart run build_runner build

# 开发时后台监听（文件修改后自动重新生成）
watch:
	dart run build_runner watch

# 清理生成文件 + 缓存
clean:
	dart run build_runner clean
	find . -name "*.freezed.dart" -o -name "*.g.dart" -delete
