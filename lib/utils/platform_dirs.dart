/// 跨平台应用自有目录工具
library;

import 'dart:io' show Platform;

/// 获取平台标准应用数据目录，拼接 [segments] 后返回完整路径。
///
/// ```dart
/// appDataDir(['agent', 'config.json'])
/// // macOS:   ~/Library/Application Support/agent/config.json
/// // Windows: C:\Users\name\AppData\Roaming\agent\config.json
/// // Linux:   ~/.config/agent/config.json
/// ```
String appDataDir(List<String> segments) {
  final base = _baseDir();
  final parts = [base, ...segments];
  return parts.join('/');
}

String _baseDir() {
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return '$home/Library/Application Support';
  } else if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA']
        ?? 'C:\\Users\\Default\\AppData\\Roaming';
    return appData;
  } else {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return '$home/.config';
  }
}
