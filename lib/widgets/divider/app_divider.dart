import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';

/// A theme-aware horizontal or vertical divider line.
///
/// Used as a visual separator in menus, lists, cards, toolbars, and
/// other layouts. Supports both [Axis.horizontal] (default) and
/// [Axis.vertical] orientations.
///
/// Theme defaults can be overridden via constructor parameters,
/// following the same pattern as [AppCard] and [AppButton].
///
/// ```dart
/// // Horizontal divider (for vertical lists, menus)
/// const AppDivider(),
///
/// // Vertical divider (for horizontal toolbars, rows)
/// const AppDivider(axis: Axis.vertical),
///
/// // Custom thickness and color
/// AppDivider(thickness: 2, color: custom.colors.accent),
/// ```
class AppDivider extends StatelessWidget {
  /// The orientation of the divider line.
  final Axis axis;

  /// The thickness of the divider line in logical pixels.
  /// Defaults to 1.0.
  final double thickness;

  /// The total space allocated for the divider widget.
  ///
  /// - For [Axis.horizontal]: the widget height (line centered vertically).
  /// - For [Axis.vertical]: the widget width (line centered horizontally).
  ///
  /// Defaults to [CustomTheme.spacing.sm] (8 px), giving ~3–4 px
  /// spacing on each side of a 1 px line.
  final double? extent;

  /// The leading space before the line.
  ///
  /// - For [Axis.horizontal]: space on the left of the line.
  /// - For [Axis.vertical]: space above the line.
  ///
  /// Defaults to 0. Pass [CustomTheme.spacing.xs] for menu-style indentation.
  final double? indent;

  /// The trailing space after the line.
  ///
  /// - For [Axis.horizontal]: space on the right of the line.
  /// - For [Axis.vertical]: space below the line.
  ///
  /// Defaults to 0. Pass [CustomTheme.spacing.xs] for menu-style indentation.
  final double? endIndent;

  /// The color of the divider line.
  ///
  /// Defaults to [CustomTheme.colors.border].
  final Color? color;

  const AppDivider({
    super.key,
    this.axis = Axis.horizontal,
    this.thickness = 1.0,
    this.extent,
    this.indent,
    this.endIndent,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final effectiveColor = color ?? custom.colors.border;
    final effectiveIndent = indent ?? 0;
    final effectiveEndIndent = endIndent ?? 0;

    if (axis == Axis.vertical) {
      return Container(
        width: extent ?? custom.spacing.sm,
        alignment: Alignment.center,
        child: Container(
          width: thickness,
          margin: EdgeInsets.only(
            top: effectiveIndent,
            bottom: effectiveEndIndent,
          ),
          color: effectiveColor,
        ),
      );
    }

    return Container(
      height: extent ?? custom.spacing.sm,
      alignment: Alignment.center,
      child: Container(
        height: thickness,
        margin: EdgeInsets.only(
          left: effectiveIndent,
          right: effectiveEndIndent,
        ),
        color: effectiveColor,
      ),
    );
  }
}
