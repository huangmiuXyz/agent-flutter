/// 跨平台应用自有目录工具
library;

import 'dart:io' show Platform;

import 'package:path_provider/path_provider.dart';

import 'package:agent/utils/platform.dart';

/// 移动端基础目录缓存（来自 path_provider，异步获取后缓存）。
String? _mobileBaseDir;

/// 初始化应用数据基础目录。
///
/// 移动端（Android/iOS）：使用 path_provider 的应用私有目录
/// （如 `/data/user/0/<package>/files`），必须在首次访问 store
/// （ConfigStore / SettingStore / CodeForgeStore）之前调用一次，
/// 由 `main.dart` 启动时统一执行。
///
/// 桌面端保持原有「环境变量」解析逻辑，此调用为 no-op。
Future<void> initAppDataDir() async {
  if (_mobileBaseDir != null) return;
  if (!isMobilePlatform) return;
  try {
    final dir = await getApplicationSupportDirectory();
    _mobileBaseDir = dir.path;
  } catch (_) {
    // path_provider 不可用（极早期/测试环境）：保持 null，
    // 后续访问仍走桌面回退逻辑，不阻断启动。
    _mobileBaseDir = null;
  }
}

/// 获取平台标准应用数据目录，拼接 [segments] 后返回完整路径。
///
/// 移动端：path_provider 应用私有目录（已由 [initAppDataDir] 缓存）。
/// 桌面端：
/// ```dart
/// appDataDir(['agent', 'config.json'])
/// // macOS:   ~/Library/Application Support/agent/config.json
/// // Windows: C:\Users\name\AppData\Roaming\agent\config.json
/// // Linux:   ~/.config/agent/config.json
/// ```
String appDataDir(List<String> segments) {
  final base = _mobileBaseDir ?? _desktopBaseDir();
  final parts = [base, ...segments];
  return parts.join('/');
}

String _desktopBaseDir() {
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

/// 移动端默认工作目录（应用私有目录下的 workspace，Rust 可直接读写）。
///
/// Android 上 Rust 文件工具基于 `std::fs`，只能访问应用私有目录；
/// SAF 选中的外部目录需导入副本后才能被 read_file/apply_patch/grep
/// 操作（见 MobileWorkDirService）。
String defaultMobileWorkDir() => appDataDir(['agent', 'workspace']);