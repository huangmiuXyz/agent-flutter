/// 编辑器文件路径状态管理。
///
/// 和 ConfigStore 同模式：signal 持有状态、跨窗口通过文件 + 广播同步。
library;

import 'dart:io';

import 'package:signals/signals.dart';

import 'package:agent/services/sync/file_watcher.dart';
import 'package:agent/utils/platform_dirs.dart';

class CodeForgeStore {
  static final instance = CodeForgeStore._();
  CodeForgeStore._() {
    _storePath = _resolveStorePath();
    _load();
    effect(() => _writeFile());
    _startWatch();
  }

  late final String _storePath;

  /// 当前编辑器正在打开的文件路径。
  final filePath = signal<String>('');

  /// 打开文件，更新 signal 后自动写文件、广播。
  void open(String path) {
    filePath.value = path;
  }

  /// 从磁盘重新加载（用于跨窗口同步）。
  void reload() {
    _load();
  }

  String _resolveStorePath() {
    return appDataDir(['agent', 'current_editor_file']);
  }

  void _load() {
    final file = File(_storePath);
    if (!file.existsSync()) return;
    try {
      final content = file.readAsStringSync().trim();
      if (content.isNotEmpty) {
        filePath.value = content;
      }
    } catch (_) {}
  }

  int _lastWriteMs = 0;

  void _writeFile() {
    final content = filePath.value;
    if (content.isEmpty) return;
    final file = File(_storePath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    _lastWriteMs = DateTime.now().millisecondsSinceEpoch;
  }

  bool _watching = false;

  void _startWatch() {
    if (_watching) return;
    _watching = true;
    watchFileChanges(
      _storePath,
      _load,
      ignoreOwnWrites: () {
        final now = DateTime.now().millisecondsSinceEpoch;
        return (now - _lastWriteMs) < 500;
      },
    );
  }
}
