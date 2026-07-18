import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';
import 'button_base.dart';

/// Theme-aware secondary (outlined) action button.
class AppSecondaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? text;
  final String? icon;
  final ButtonStyle? style;
  final bool disabled;
  final bool hoverStyle;
  final ButtonSize size;

  const AppSecondaryButton({
    super.key,
    this.text,
    this.icon,
    this.onPressed,
    this.style,
    this.disabled = false,
    this.hoverStyle = true,
    this.size = ButtonSize.md,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final sizing = resolveButtonSizing(custom, size);
    final isDisabled = disabled || onPressed == null;
    final foregroundColor = isDisabled
        ? custom.colors.textDisabled
        : custom.colors.textPrimary;

    final button = TextButton(
      onPressed: isDisabled ? null : onPressed,
      style: _buildStyle(custom, sizing).merge(style),
      child: _buildChild(custom, sizing.iconSize, foregroundColor),
    );

    if (size == ButtonSize.sm) return UnconstrainedBox(child: button);
    return UnconstrainedBox(
      child: SizedBox(height: sizing.height, child: button),
    );
  }

  Widget _buildChild(CustomTheme custom, double iconSize, Color foregroundColor) {
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(icon!, size: iconSize, color: foregroundColor),
          SizedBox(width: custom.spacing.sm),
          AppText(text ?? '', color: foregroundColor),
        ],
      );
    }
    return AppText(text ?? '', color: foregroundColor);
  }

  ButtonStyle _buildStyle(CustomTheme custom, ButtonSizing sizing) {
    return ButtonStyle(
      backgroundColor: _background(custom),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(vertical: 0, horizontal: custom.spacing.md),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: sizing.borderRadius,
          side: BorderSide(color: custom.colors.borderSubtle),
        ),
      ),
      elevation: WidgetStateProperty.all(1),
    );
  }

  WidgetStateProperty<Color?> _background(CustomTheme custom) {
    if (!hoverStyle) {
      return WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return custom.colors.panel;
        return custom.colors.background;
      });
    }
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return custom.colors.panel;
      if (states.contains(WidgetState.pressed)) return custom.colors.selected;
      if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
        return custom.colors.hover;
      }
      return custom.colors.background;
    });
  }
}
