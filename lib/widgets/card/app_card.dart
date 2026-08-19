import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';

/// Scroll behavior that hides the scrollbar and disables rubber-band
/// bouncing (platform default on macOS/iOS would bounce at the edges).
class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

/// A styled card container used for context menus, dropdowns, tooltips,
/// and other floating overlay panels.
///
/// Provides theme-driven decoration (background, border, shadow, radius)
/// with optional intrinsic width and scroll constraints.
class AppCard extends StatelessWidget {
  final Widget child;
  final double? minWidth;
  final double? maxWidth;
  final double? maxHeight;
  final double? stepWidth;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final bool scrollable;

  /// 面板顶部固定区域（如搜索条），不随 [child] 滚动。
  /// 仅 [scrollable] 为 true 且提供 [maxHeight] 时生效。
  final Widget? header;

  const AppCard({
    super.key,
    required this.child,
    this.minWidth,
    this.maxWidth,
    this.maxHeight,
    this.stepWidth,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.scrollable = true,
    this.header,
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
      // stepWidth 仅显式传入时按整倍数取整；null 时不取整（宽度自适应内容）。
      // 注意不能传 0：_applyStep 中 x/0 → Infinity → Infinity*0 → NaN
      stepWidth: stepWidth,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minWidth ?? 0,
          maxWidth: maxWidth ?? double.infinity,
          maxHeight: maxHeight ?? double.infinity,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: effectiveRadius,
            border: effectiveBorder,
            boxShadow: effectiveShadow,
          ),
          child: Padding(
            padding: effectivePadding,
            child: scrollable
                ? ScrollConfiguration(
                    behavior: const _NoScrollbarBehavior(),
                    child: header != null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              header!,
                              Flexible(
                                child: SingleChildScrollView(child: child),
                              ),
                            ],
                          )
                        : SingleChildScrollView(child: child),
                  )
                : child,
          ),
        ),
      ),
    );
  }
}
