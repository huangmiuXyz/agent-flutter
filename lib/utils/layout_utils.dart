import 'dart:math' as math;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

import 'package:agent/utils/responsive.dart';

/// 阅读宽度 — 主屏物理宽度的一半（逻辑像素）。
/// 桌面应用运行期间屏幕分辨率不会变化，一次计算即可。
final double readingWidth = () {
  final display = PlatformDispatcher.instance.displays.first;
  return display.size.width / display.devicePixelRatio / 2;
}();

/// 阅读宽度上限（紧凑宽度下）。
const double _compactMaxReadingWidth = 720;

/// 阅读宽度（按上下文自适应）。
///
/// - 普通宽度：沿用 [readingWidth]（主屏一半），桌面行为不变
/// - 紧凑宽度（手机 / <600dp 窄窗口）：`min(可用宽度 − 边距, 720)`，
///   避免 360dp 手机屏下内容被压到半屏宽
double readingWidthFor(BuildContext context) {
  if (!isCompactWidth(context)) return readingWidth;
  final width = MediaQuery.sizeOf(context).width;
  return math.min(width - 16, _compactMaxReadingWidth);
}
