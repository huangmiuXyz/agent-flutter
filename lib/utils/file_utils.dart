/// 文件系统工具函数
library;

import 'dart:io';

/// 用系统默认编辑器打开文件。
void openFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return;
  final cmd = Platform.isMacOS
      ? 'open'
      : Platform.isWindows
          ? 'start'
          : 'xdg-open';
  Process.run(cmd, [path], runInShell: true);
}
