import 'package:flutter/material.dart';
import 'package:agent/theme/custom_theme.dart';

/// Visual size variants shared across all button types.
enum ButtonSize { sm, md, lg }

/// Pre-computed sizing values for a button.
class ButtonSizing {
  final double height;
  final double iconSize;
  final BorderRadius borderRadius;

  const ButtonSizing({
    required this.height,
    required this.iconSize,
    required this.borderRadius,
  });
}

/// Resolve button sizing from theme for a given size.
ButtonSizing resolveButtonSizing(CustomTheme custom, ButtonSize size) {
  final height = switch (size) {
    ButtonSize.sm => custom.controls.smallHeight,
    ButtonSize.md => custom.controls.mediumHeight,
    ButtonSize.lg => custom.controls.largeHeight,
  };
  final iconSize = switch (size) {
    ButtonSize.sm => custom.typography.captionSize,
    ButtonSize.md => custom.typography.subtitleSize,
    ButtonSize.lg => custom.typography.titleSize,
  };
  final borderRadius = switch (size) {
    ButtonSize.sm || ButtonSize.md => custom.radii.xs,
    ButtonSize.lg => custom.radii.sm,
  };
  return ButtonSizing(height: height, iconSize: iconSize, borderRadius: borderRadius);
}
