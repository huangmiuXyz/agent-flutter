import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';

/// Controls the visual density of [AppDivider].
///
/// * [AppDividerSize.normal] — standard density (default).
/// * [AppDividerSize.small] — compact density for menus.
enum AppDividerSize { normal, small }

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
  /// Defaults to [CustomTheme.colors.separator].
  final Color? color;

  /// Visual density. [AppDividerSize.small] reduces the [extent].
  final AppDividerSize size;

  const AppDivider({
    super.key,
    this.axis = Axis.horizontal,
    this.thickness = 1.0,
    this.extent,
    this.indent,
    this.endIndent,
    this.color,
    this.size = AppDividerSize.normal,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final effectiveColor = color ?? custom.colors.separator;
    final effectiveIndent =
        indent ?? (size == AppDividerSize.small ? custom.spacing.xs : 0);
    final effectiveEndIndent =
        endIndent ?? (size == AppDividerSize.small ? custom.spacing.xs : 0);
    final effectiveExtent =
        extent ??
        (size == AppDividerSize.small ? custom.spacing.xs : custom.spacing.sm);

    if (axis == Axis.vertical) {
      return Container(
        width: effectiveExtent,
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
      height: effectiveExtent,
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
