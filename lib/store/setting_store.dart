import 'dart:convert';
import 'dart:io';

import 'package:signals/signals.dart';

import 'package:agent/services/sync/file_watcher.dart';
import 'package:agent/theme/app_tokens.dart';
import 'package:agent/utils/platform_dirs.dart';

/// 显示/主题设置持久化存储（setting.json）。
///
/// 与智能体配置（ConfigStore / config.json）分离，各自独立文件。
class SettingStore {
  static final instance = SettingStore._();
  SettingStore._() {
    _resolvePath();
    _load();

    // 自动持久化：data 信号一变，立即写文件
    effect(() => _writeFile());

    // 监听外部文件修改（手动编辑 setting.json）
    _startWatch();
  }

  late final String path;

  // ── setting.json 全量内容 ──

  final data = signal(<String, dynamic>{});

  static Map<String, dynamic> _defaults() => {'fontFamily': kDefaultFontFamily};

  // ── 便捷读取 ──

  String get fontFamily =>
      data.value['fontFamily'] as String? ?? kDefaultFontFamily;

  void setFontFamily(String family) {
    mutate((d) => d['fontFamily'] = family);
  }

  // ── 便捷更新 ──

  /// 从磁盘重新加载配置（用于窗口间同步）。
  void reload() {
    _load();
  }

  void mutate(void Function(Map<String, dynamic> map) fn) {
    final copy = Map<String, dynamic>.from(data.value);
    fn(copy);
    data.value = copy;
  }

  // ── 内部 ──

  void _resolvePath() {
    const compileEnv = String.fromEnvironment('SETTING_PATH');
    if (compileEnv.isNotEmpty) {
      path = compileEnv;
      return;
    }

    final runtimeEnv = Platform.environment['AGENT_SETTING_PATH'];
    if (runtimeEnv != null && runtimeEnv.isNotEmpty) {
      path = runtimeEnv;
      return;
    }

    path = appDataDir(['agent', 'setting.json']);
  }

  void _load() {
    final file = File(path);
    if (!file.existsSync()) {
      data.value = _defaults();
      return;
    }
    try {
      final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final merged = Map<String, dynamic>.from(_defaults());
      merged.addAll(raw);
      if (data.value == merged) return;
      data.value = merged;
    } catch (_) {
      if (data.value.isEmpty) {
        data.value = _defaults();
      }
    }
  }

  int _lastWriteMs = 0;

  void _writeFile() {
    final file = File(path);
    final content =
        '${const JsonEncoder.withIndent('  ').convert(data.value)}\n';
    if (file.existsSync()) {
      try {
        final existing = file.readAsStringSync();
        if (existing == content) return;
        jsonDecode(existing);
      } catch (_) {
        return;
      }
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    _lastWriteMs = DateTime.now().millisecondsSinceEpoch;
  }

  bool _watching = false;

  void _startWatch() {
    if (_watching) return;
    _watching = true;
    watchFileChanges(
      path,
      () {
        reload();
      },
      ignoreOwnWrites: () {
        final now = DateTime.now().millisecondsSinceEpoch;
        return (now - _lastWriteMs) < 500;
      },
    );
  }
}
