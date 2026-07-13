import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';

// Re-export so callers can pass AppTextVariant without importing app_text.dart.
export 'package:agent/widgets/text/app_text.dart' show AppTextVariant;

class AppList extends StatelessWidget {
  final double? width;
  final EdgeInsetsGeometry? containerPadding;
  final double? itemGap;
  final BorderRadiusGeometry? containerRadius;
  final Color? containerColor;
  final List<Widget> children;

  const AppList({
    super.key,
    this.width,
    this.containerPadding,
    this.itemGap,
    this.containerRadius,
    this.containerColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return Container(
      width: width,
      padding: containerPadding ?? EdgeInsets.all(custom.spacingSm),
      decoration: BoxDecoration(
        color: containerColor ?? Colors.transparent,
        borderRadius: (containerRadius ?? custom.radiusSm) as BorderRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: itemGap ?? custom.spacingXs),
            children[i],
          ],
        ],
      ),
    );
  }
}

class AppListItem extends HookWidget {
  final String? icon;
  final String label;
  final String? trailing;
  final bool active;
  final bool disabled;
  final VoidCallback? onTap;

  final double? itemHeight;
  final EdgeInsetsGeometry? itemPadding;
  final BorderRadiusGeometry? itemRadius;
  final Color? itemColor;
  final Color? labelColor;
  final double? iconSize;
  final double? iconLabelGap;

  /// Optional widget placed after [trailing] text (e.g. submenu chevron).
  final Widget? trailingWidget;

  /// Override the label text variant. Defaults to [AppTextVariant.body].
  final AppTextVariant? labelVariant;

  /// When true, the item height is determined by its content (padding + text)
  /// instead of a fixed [itemHeight] or the default [CustomTheme.controls.mediumHeight].
  final bool intrinsicHeight;

  /// Called when hover state changes. Provides the item's RenderBox.
  final void Function(bool isHovered, RenderBox renderBox)? onHover;

  const AppListItem({
    super.key,
    this.icon,
    required this.label,
    this.trailing,
    this.active = false,
    this.disabled = false,
    this.onTap,
    this.itemHeight,
    this.itemPadding,
    this.itemRadius,
    this.itemColor,
    this.labelColor,
    this.iconSize,
    this.iconLabelGap,
    this.trailingWidget,
    this.labelVariant,
    this.intrinsicHeight = false,
    this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final isHovered = useState(false);
    final isPressed = useState(false);
    final enabled = !disabled;

    final padding =
        itemPadding ?? EdgeInsets.symmetric(horizontal: custom.spacing.sm);
    final radius = (itemRadius ?? custom.radii.sm) as BorderRadius;
    final iconSz = iconSize ?? custom.typography.titleSize;
    final gap = iconLabelGap ?? custom.spacing.sm;

    final bgColor = switch ((active, isPressed.value, isHovered.value)) {
      (true, _, _) => itemColor ?? custom.colors.selected,
      (_, true, _) when enabled => itemColor ?? custom.colors.selected,
      (_, _, true) when enabled => itemColor ?? custom.colors.hover,
      _ => Colors.transparent,
    };
    final foreground = enabled
        ? (labelColor ?? custom.colors.textPrimary)
        : custom.colors.textDisabled;

    final fixedHeight = intrinsicHeight
        ? null
        : (itemHeight ?? custom.controls.mediumHeight);

    Widget child = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Material(
        color: bgColor,
        borderRadius: radius,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: radius,
          onHover: (value) {
            isHovered.value = value;
            if (onHover != null) {
              final box = context.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize) {
                onHover!(value, box);
              }
            }
          },
          onHighlightChanged: (value) => isPressed.value = value,
          splashFactory: NoSplash.splashFactory,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                if (icon != null) ...[
                  AppIcon(icon!, size: iconSz, color: foreground),
                  SizedBox(width: gap),
                ],
                Expanded(
                  child: AppText(
                    label,
                    variant: labelVariant ?? AppTextVariant.body,
                    color: foreground,
                  ),
                ),
                if (trailing != null)
                  Padding(
                    padding: EdgeInsets.only(left: custom.spacing.sm),
                    child: AppText(
                      trailing!,
                      variant: AppTextVariant.caption,
                      color: enabled
                          ? custom.colors.textSecondary
                          : custom.colors.textDisabled,
                    ),
                  ),
                if (trailingWidget != null)
                  Padding(
                    padding: EdgeInsets.only(left: custom.spacing.sm),
                    child: trailingWidget,
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (fixedHeight != null) {
      child = SizedBox(height: fixedHeight, child: child);
    }
    return child;
  }
}
