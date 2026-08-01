/// setting_store — 显示/主题设置持久化存储（setting.json）
///
/// 与智能体配置（ConfigStore / config.json）分离，各自独立文件。
/// 加载/写文件/外部监听由 [JsonFileSignalStore] 基类提供。
library;

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:agent/store/file_signal_store.dart';
import 'package:agent/theme/app_tokens.dart';
import 'package:agent/utils/platform_dirs.dart';

class SettingStore extends JsonFileSignalStore {
  static final instance = SettingStore._();
  SettingStore._() : super(_resolvePath());

  @override
  Map<String, dynamic> defaults() => {
    'fontFamily': kDefaultFontFamily,
    'themeMode': 'system',
  };

  // ── 便捷读取 ──

  String get fontFamily =>
      data.value['fontFamily'] as String? ?? kDefaultFontFamily;

  /// 持久化的主题模式，缺失/非法值时回退到跟随系统。
  ThemeMode get themeMode {
    return switch (data.value['themeMode']) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  void setFontFamily(String family) {
    mutate((d) => d['fontFamily'] = family);
  }

  void setThemeMode(ThemeMode mode) {
    mutate((d) => d['themeMode'] = mode.name);
  }

  // ── 路径解析 ──

  static String _resolvePath() {
    const compileEnv = String.fromEnvironment('SETTING_PATH');
    if (compileEnv.isNotEmpty) return compileEnv;

    final runtimeEnv = Platform.environment['AGENT_SETTING_PATH'];
    if (runtimeEnv != null && runtimeEnv.isNotEmpty) return runtimeEnv;

    return appDataDir(['agent', 'setting.json']);
  }
}
