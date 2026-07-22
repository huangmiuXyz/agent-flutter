import 'dart:ui' show PlatformDispatcher;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'layout_utils.g.dart';

/// Cached reading width – half of the physical primary display width.
/// Computed once because the primary display resolution doesn't change
/// during the app's lifetime on desktop.
@riverpod
double readingWidth(Ref ref) {
  final display = PlatformDispatcher.instance.displays.first;
  return display.size.width / display.devicePixelRatio / 2;
}


