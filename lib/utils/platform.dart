/// 平台判断工具。
///
/// 使用 [defaultTargetPlatform] 而非 `dart:io Platform`：
/// - 测试环境可注入目标平台（debugDefaultTargetPlatformOverride）
/// - 不依赖 `dart:io`，Web/移动端均可用
library;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// 当前是否为桌面平台（Windows / macOS / Linux）。
bool get isDesktopPlatform {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
      return true;
    default:
      return false;
  }
}

/// 当前是否为移动平台（Android / iOS）。
bool get isMobilePlatform {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return true;
    default:
      return false;
  }
}