import 'dart:convert';
import 'dart:io';

import 'package:signals/signals.dart';

import 'package:agent/utils/platform_dirs.dart';

class ConfigStore {
  static final instance = ConfigStore._();
  ConfigStore._() {
    configPath = _resolveConfigPath();
    dbPath = _resolveDbPath();
    _load();

    // 自动持久化：data 信号一变，立即写文件
    effect(() => _writeFile());
  }

  // ── 路径（一次性解析，不含信号）──

  late final String configPath;
  late final String dbPath;

  // ── config.json 全量内容（信号，直接当 Map 读写）──

  final data = signal(<String, dynamic>{});

  // ── 便捷更新 ──

  /// 修改数据，改完自动写文件 + 通知 UI
  void mutate(void Function(Map<String, dynamic> map) fn) {
    final copy = Map<String, dynamic>.from(data.value);
    fn(copy);
    data.value = copy;
  }

  // ── 内部 ──

  void _load() {
    final file = File(configPath);
    if (!file.existsSync()) return;
    try {
      data.value = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      data.value = {};
    }
  }

  void _writeFile() {
    final file = File(configPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(data.value)}\n',
    );
  }

  // ── 路径解析（原有逻辑）──

  bool _inProjectDir() {
    return File('./config.json').existsSync() ||
        File('./pubspec.yaml').existsSync() ||
        Directory('./data').existsSync();
  }

  String _resolveConfigPath() {
    const compileEnv = String.fromEnvironment('CONFIG_PATH');
    if (compileEnv.isNotEmpty) return compileEnv;

    final runtimeEnv = Platform.environment['AGENT_CONFIG_PATH'];
    if (runtimeEnv != null && runtimeEnv.isNotEmpty) return runtimeEnv;

    if (_inProjectDir()) return '../agent-flutter-cli/config.json';

    return appDataDir(['agent', 'config.json']);
  }

  String _resolveDbPath() {
    const compileEnv = String.fromEnvironment('DB_PATH');
    if (compileEnv.isNotEmpty) return compileEnv;

    final runtimeEnv = Platform.environment['AGENT_DB_PATH'];
    if (runtimeEnv != null && runtimeEnv.isNotEmpty) return runtimeEnv;

    if (_inProjectDir()) return '../agent-flutter-cli/data/data';

    return appDataDir(['agent', 'data', 'data']);
  }
}
