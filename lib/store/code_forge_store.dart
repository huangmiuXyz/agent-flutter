/// 编辑器文件路径状态管理。
///
/// 和 ConfigStore 同模式：signal 持有状态、跨窗口通过文件 + 广播同步。
/// 加载/写文件/外部监听由 [FileSignalStore] 基类提供。
library;

import 'dart:io';

import 'package:signals/signals.dart';

import 'package:agent/store/file_signal_store.dart';
import 'package:agent/utils/platform_dirs.dart';

class CodeForgeStore extends FileSignalStore {
  static final instance = CodeForgeStore._();
  CodeForgeStore._() : super(_resolveStorePath());

  /// 当前编辑器正在打开的文件路径。
  ///
  /// `late final`：构造函数中 [loadFromDisk] 首次访问时才初始化。
  late final filePath = signal<String>('');

  /// 打开文件，更新 signal 后自动写文件、广播。
  void open(String path) {
    filePath.value = path;
  }

  @override
  void loadFromDisk() {
    final file = File(path);
    if (!file.existsSync()) return;
    try {
      final content = file.readAsStringSync().trim();
      if (content.isNotEmpty) {
        filePath.value = content;
      }
    } catch (_) {}
  }

  @override
  bool writeToDisk() {
    final content = filePath.value;
    if (content.isEmpty) return false;
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    return true;
  }

  static String _resolveStorePath() {
    return appDataDir(['agent', 'current_editor_file']);
  }
}
