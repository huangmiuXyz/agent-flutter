import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';

class AppList extends StatelessWidget {
  final double? width;
  final EdgeInsetsGeometry? containerPadding;
  final double? itemGap;
  final BorderRadiusGeometry? containerRadius;
  final Color? containerColor;
  final List<AppListItem> children;

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
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final isHovered = useState(false);
    final isPressed = useState(false);
    final enabled = !disabled;

    final height = itemHeight ?? custom.controls.mediumHeight;
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

    return SizedBox(
      height: height,
      child: Material(
        color: bgColor,
        borderRadius: radius,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: radius,
          onHover: (value) => isHovered.value = value,
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
                    variant: AppTextVariant.body,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
