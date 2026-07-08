.PHONY: run build clean

# 生成代码 + 启动 app
run:
	dart run build_runner build --delete-conflicting-outputs
	flutter run

# 仅重新生成代码
build:
	dart run build_runner build --delete-conflicting-outputs

# 开发时后台监听（文件修改后自动重新生成）
watch:
	dart run build_runner watch

# 清理生成文件 + 缓存
clean:
	dart run build_runner clean
	find . -name "*.freezed.dart" -o -name "*.g.dart" -delete
