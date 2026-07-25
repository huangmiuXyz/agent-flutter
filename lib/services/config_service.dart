/// 配置相关工具函数 — 路径解析（纯函数，无状态）
library;

import 'dart:io';

import 'package:agent/utils/platform_dirs.dart';

/// 当前是否在项目源码目录（开发环境）
bool _inProjectDir() {
  return File('./config.json').existsSync() ||
      File('./pubspec.yaml').existsSync() ||
      Directory('./data').existsSync();
}

/// 解析配置文件路径，逻辑迁移至 [ConfigStore]
/// 保留仅作为参考，不再直接使用。
@Deprecated('Use ConfigStore.instance.configPath instead')
String resolveConfigPath() {
  const compileEnv = String.fromEnvironment('CONFIG_PATH');
  if (compileEnv.isNotEmpty) return compileEnv;

  final runtimeEnv = Platform.environment['AGENT_CONFIG_PATH'];
  if (runtimeEnv != null && runtimeEnv.isNotEmpty) return runtimeEnv;

  if (_inProjectDir()) {
    return '../agent-flutter-cli/config.json';
  }

  return appDataDir(['agent', 'config.json']);
}

/// 解析数据库路径，逻辑迁移至 [ConfigStore]
@Deprecated('Use ConfigStore.instance.dbPath instead')
String resolveDbPath() {
  const compileEnv = String.fromEnvironment('DB_PATH');
  if (compileEnv.isNotEmpty) return compileEnv;

  final runtimeEnv = Platform.environment['AGENT_DB_PATH'];
  if (runtimeEnv != null && runtimeEnv.isNotEmpty) return runtimeEnv;

  if (_inProjectDir()) {
    return '../agent-flutter-cli/data/data';
  }

  return appDataDir(['agent', 'data', 'data']);
}
