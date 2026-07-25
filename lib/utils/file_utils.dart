/// 文件系统工具函数
library;

import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';

/// 编辑器窗口控制器（单例，复用已创建的窗口）。
WindowController? _editorWindow;

/// 在编辑器子窗口中打开文件。
///
/// 对于 JSON 等代码文件，会在应用内编辑器（code_forge）中打开，
/// 而非系统默认应用。
void openFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return;

  // 尝试在编辑器窗口中打开
  _openInEditor(path).catchError((_) {
    // 回退到系统默认应用
    _openWithSystemDefault(path);
  });
}

Future<void> _openInEditor(String path) async {
  try {
    var w = _editorWindow;
    if (w == null) {
      w = await WindowController.create(
        WindowConfiguration(
          arguments: 'editor:$path',
          hiddenAtLaunch: true,
        ),
      );
      _editorWindow = w;
    }
    await w.show();
  } catch (e) {
    // 编辑器打开失败，走系统默认
    rethrow;
  }
}

void _openWithSystemDefault(String path) {
  final cmd = Platform.isMacOS
      ? 'open'
      : Platform.isWindows
          ? 'start'
          : 'xdg-open';
  Process.run(cmd, [path], runInShell: true);
}
