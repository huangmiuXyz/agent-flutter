import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';
import 'button_base.dart';

/// Theme-aware text-only button (no background/border).
///
/// Text color changes on hover via [WidgetStateProperty] — no manual state.
class AppTextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? text;
  final String? icon;
  final ButtonStyle? style;
  final bool disabled;
  final ButtonSize size;

  const AppTextButton({
    super.key,
    this.text,
    this.icon,
    this.onPressed,
    this.style,
    this.disabled = false,
    this.size = ButtonSize.md,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final sizing = resolveButtonSizing(custom, size);
    final isDisabled = disabled || onPressed == null;

    final defaultFg = custom.colors.textSecondary;
    final hoverFg = custom.colors.accent;
    final disabledFg = custom.colors.textDisabled;

    final button = TextButton(
      onPressed: isDisabled ? null : onPressed,
      style: _buildStyle(
        custom,
        sizing,
        defaultFg,
        hoverFg,
        disabledFg,
      ).merge(style),
      child: _buildChild(
        custom,
        sizing.iconSize,
        isDisabled ? disabledFg : defaultFg,
      ),
    );

    return UnconstrainedBox(alignment: Alignment.centerLeft, child: button);
  }

  Widget _buildChild(
    CustomTheme custom,
    double iconSize,
    Color foregroundColor,
  ) {
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

  ButtonStyle _buildStyle(
    CustomTheme custom,
    ButtonSizing sizing,
    Color defaultFg,
    Color hoverFg,
    Color disabledFg,
  ) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.all(Colors.transparent),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return disabledFg;
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return hoverFg;
        }
        return defaultFg;
      }),
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(
          horizontal: custom.spacing.xs,
          vertical: custom.spacing.xs,
        ),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: sizing.borderRadius),
      ),
      elevation: WidgetStateProperty.all(0),
    );
  }
}
