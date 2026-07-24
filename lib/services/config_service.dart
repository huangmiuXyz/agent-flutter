/// Config Service — 配置文件读写、路径管理、默认模型持久化
///
/// 所有与 config.json 相关的逻辑集中在此文件。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:agent/utils/platform_dirs.dart';

part 'config_service.g.dart';

// ─── 配置路径 ───────────────────────────────────────────────────

/// 当前是否在项目源码目录（开发环境）
///
/// 通过检查项目根目录标识文件判断，避免将生产环境的 cwd 误判为开发目录。
bool _inProjectDir() {
  return File('./config.json').existsSync() ||
      File('./pubspec.yaml').existsSync() ||
      Directory('./data').existsSync();
}

/// 配置路径
///
/// 优先级：
/// 1. --dart-define=CONFIG_PATH 编译时指定
/// 2. AGENT_CONFIG_PATH 环境变量
/// 3. 开发环境（项目目录下）→ ./config.json
/// 4. 生产环境 → 平台标准数据目录
@riverpod
class ConfigPath extends _$ConfigPath {
  @override
  String build() {
    const compileEnv = String.fromEnvironment('CONFIG_PATH');
    if (compileEnv.isNotEmpty) return compileEnv;

    final runtimeEnv = Platform.environment['AGENT_CONFIG_PATH'];
    if (runtimeEnv != null && runtimeEnv.isNotEmpty) return runtimeEnv;

    if (_inProjectDir()) {
      return '../agent-flutter-cli/config.json';
    }

    return appDataDir(['agent', 'config.json']);
  }
}

/// 数据库路径（可外部覆盖）
///
/// 优先级：
/// 1. --dart-define=DB_PATH 编译时指定
/// 2. AGENT_DB_PATH 环境变量
/// 3. 开发环境 → 使用后端的目录（agent-flutter-cli/data/data）
/// 4. 生产环境 → 平台标准数据目录
@riverpod
class DbPath extends _$DbPath {
  @override
  String build() {
    const compileEnv = String.fromEnvironment('DB_PATH');
    if (compileEnv.isNotEmpty) return compileEnv;

    final runtimeEnv = Platform.environment['AGENT_DB_PATH'];
    if (runtimeEnv != null && runtimeEnv.isNotEmpty) return runtimeEnv;

    if (_inProjectDir()) {
      return '../agent-flutter-cli/data/data';
    }

    return appDataDir(['agent', 'data', 'data']);
  }
}

// ─── 底层 JSON 文件读写 ─────────────────────────────────────────

/// 基于单文件 JSON 的配置存储，以 `.` 分隔的路径读写任意层级。
class ConfigFileStore {
  final String configPath;

  ConfigFileStore(this.configPath);

  Map<String, dynamic> readAll() {
    final file = File(configPath);
    if (!file.existsSync()) return {};
    try {
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  void writeAll(Map<String, dynamic> data) {
    final file = File(configPath);
    file.parent.createSync(recursive: true);
    final content = const JsonEncoder.withIndent('  ').convert(data);
    file.writeAsStringSync('$content\n');
  }

  String? readPath(String path) {
    final root = readAll();
    var current = root as dynamic;
    for (final part in path.split('.')) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }
    if (current == null) return null;
    return jsonEncode(current);
  }

  void writePath(String path, dynamic value) {
    final root = readAll();
    final parts = path.split('.');
    var current = root as dynamic;
    for (int i = 0; i < parts.length - 1; i++) {
      if (current is! Map) return;
      current = current.putIfAbsent(parts[i], () => <String, dynamic>{});
    }
    if (current is Map) {
      current[parts.last] = value;
    }
    writeAll(root);
  }
}

/// ConfigFileStore 全局单例
@riverpod
ConfigFileStore configFileStore(Ref ref) {
  final configPath = ref.watch(configPathProvider);
  return ConfigFileStore(configPath);
}

// ─── 默认模型配置 ───────────────────────────────────────────────

/// 默认模型配置 — 自动持久化到 config.json 的 `default_model` 字段
@riverpod
class DefaultModel extends _$DefaultModel {
  @override
  Map<String, String>? build() {
    final store = ref.read(configFileStoreProvider);
    final raw = store.readPath('default_model');
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final provider = decoded['provider'] as String?;
        final model = decoded['model'] as String?;
        if (provider != null && model != null) {
          return {'provider': provider, 'model': model};
        }
      } catch (_) {}
    }
    return null;
  }

  /// 设置默认值：同步更新 state，同步写文件
  void setDefault(String provider, String model) {
    state = {'provider': provider, 'model': model};
    final store = ref.read(configFileStoreProvider);
    store.writePath('default_model', {'provider': provider, 'model': model});
  }
}

// ─── 快捷方法 ───────────────────────────────────────────────────

/// 保存当前选择的提供商（保留已选的 model）
void saveDefaultProvider(WidgetRef ref, String provider) {
  final current = ref.read(defaultModelProvider);
  final model = (current != null && current['model']!.isNotEmpty)
      ? current['model']!
      : '';
  ref.read(defaultModelProvider.notifier).setDefault(provider, model);
}

/// 保存当前选择的模型（保留已选的 provider，为空时跳过）
void saveDefaultModel(WidgetRef ref, String model) {
  final current = ref.read(defaultModelProvider);
  final provider = (current != null && current['provider']!.isNotEmpty)
      ? current['provider']!
      : '';
  if (provider.isNotEmpty) {
    ref.read(defaultModelProvider.notifier).setDefault(provider, model);
  }
}
