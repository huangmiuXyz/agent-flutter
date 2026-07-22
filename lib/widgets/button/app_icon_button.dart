import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'button_base.dart';

/// Theme-aware icon-only button with optional tooltip.
class AppIconButton extends StatelessWidget {
  final String icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final ButtonStyle? style;
  final bool disabled;
  final bool hoverStyle;
  final ButtonSize size;
  final Color? backgroundColor;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.style,
    this.disabled = false,
    this.hoverStyle = true,
    this.size = ButtonSize.md,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final sizing = resolveButtonSizing(custom, size);
    final isDisabled = disabled || onPressed == null;
    final foregroundColor = isDisabled
        ? custom.colors.textDisabled
        : custom.colors.textPrimary;

    Widget iconWidget = AppIcon(
      icon,
      size: sizing.iconSize,
      color: foregroundColor,
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      iconWidget = Tooltip(
        message: tooltip!,
        decoration: BoxDecoration(
          color: custom.colors.menuBackground,
          border: Border.all(color: custom.colors.menuBorder),
          borderRadius: custom.radii.xs,
          boxShadow: custom.shadows.small,
        ),
        textStyle: custom.typography.styleForSize(
          custom.typography.captionSize,
          custom.colors.textPrimary,
        ),
        child: iconWidget,
      );
    }

    final button = SizedBox(
      width: sizing.height,
      height: sizing.height,
      child: TextButton(
        onPressed: isDisabled ? null : onPressed,
        style: _buildStyle(custom, sizing, backgroundColor).merge(style),
        child: iconWidget,
      ),
    );

    return UnconstrainedBox(child: button);
  }

  ButtonStyle _buildStyle(
    CustomTheme custom,
    ButtonSizing sizing,
    Color? backgroundColorOverride,
  ) {
    if (backgroundColorOverride != null) {
      return ButtonStyle(
        backgroundColor: WidgetStateProperty.all(backgroundColorOverride),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        padding: WidgetStateProperty.all(EdgeInsets.all(custom.spacing.xs)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: sizing.borderRadius),
        ),
        elevation: WidgetStateProperty.all(0),
      );
    }
    if (!hoverStyle) {
      return ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        padding: WidgetStateProperty.all(EdgeInsets.all(custom.spacing.xs)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: sizing.borderRadius),
        ),
        elevation: WidgetStateProperty.all(0),
      );
    }
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return custom.colors.hover;
        }
        return Colors.transparent;
      }),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      padding: WidgetStateProperty.all(EdgeInsets.all(custom.spacing.xs)),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: sizing.borderRadius),
      ),
      elevation: WidgetStateProperty.all(0),
    );
  }
}
