import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';

/// Scroll behavior that hides the scrollbar.
class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}

/// A styled card container used for context menus, dropdowns, tooltips,
/// and other floating overlay panels.
///
/// Provides theme-driven decoration (background, border, shadow, radius)
/// with optional intrinsic width and scroll constraints.
class AppCard extends StatelessWidget {
  final Widget child;
  final double? minWidth;
  final double? maxHeight;
  final double? stepWidth;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final bool scrollable;

  const AppCard({
    super.key,
    required this.child,
    this.minWidth,
    this.maxHeight,
    this.stepWidth,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    final effectivePadding = padding ?? EdgeInsets.all(custom.spacing.xs);
    final effectiveBg = backgroundColor ?? custom.colors.cardBackground;
    final effectiveRadius = borderRadius ?? custom.radii.sm;
    final effectiveBorder =
        border ?? Border.all(color: custom.colors.cardBorder, width: 1);
    final effectiveShadow = boxShadow ?? custom.shadows.small;

    return IntrinsicWidth(
      stepWidth: stepWidth ?? minWidth ?? 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minWidth ?? 0,
          maxHeight: maxHeight ?? double.infinity,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: effectiveRadius,
            border: effectiveBorder,
            boxShadow: effectiveShadow,
          ),
          child: scrollable
              ? ScrollConfiguration(
                  behavior: const _NoScrollbarBehavior(),
                  child: SingleChildScrollView(padding: effectivePadding, child: child),
                )
              : Padding(padding: effectivePadding, child: child),
        ),
      ),
    );
  }
}
