import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';

/// Cached reading width – half of the physical primary display width.
/// Computed once because the primary display resolution doesn't change
/// during the app's lifetime on desktop.
final readingWidthProvider = Provider<double>((ref) {
  final display = PlatformDispatcher.instance.displays.first;
  return display.size.width / display.devicePixelRatio / 2;
});

/// Returns the reading width as half of the physical display width.
/// Uses the primary display (monitor) resolution, not the window size,
/// so the value stays fixed regardless of window resizing.
///
/// Prefer [readingWidthProvider] in Riverpod-aware widgets; keep this
/// function for legacy convenience use in non-Riverpod contexts.
double readingWidth(BuildContext context) {
  final display = PlatformDispatcher.instance.displays.first;
  return display.size.width / display.devicePixelRatio / 2;
}
