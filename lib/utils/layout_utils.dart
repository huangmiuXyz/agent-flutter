import 'dart:ui' show PlatformDispatcher;

/// 阅读宽度 — 主屏物理宽度的一半（逻辑像素）。
/// 桌面应用运行期间屏幕分辨率不会变化，一次计算即可。
final double readingWidth = () {
  final display = PlatformDispatcher.instance.displays.first;
  return display.size.width / display.devicePixelRatio / 2;
}();
