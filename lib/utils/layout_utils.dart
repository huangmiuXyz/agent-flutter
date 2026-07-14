import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';

/// Returns the reading width as half of the physical display width.
/// Uses the primary display (monitor) resolution, not the window size,
/// so the value stays fixed regardless of window resizing.
double readingWidth(BuildContext context) {
  final display = PlatformDispatcher.instance.displays.first;
  return display.size.width / display.devicePixelRatio / 2;
}
