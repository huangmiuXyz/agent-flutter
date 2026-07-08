import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';

const _kHoverOpacity = 0.88;
const _kPressedOpacity = 0.82;

enum ButtonVariant { primary, secondary, text, iconOnly }

enum ButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? text;
  final String? icon;
  final ButtonStyle? style;
  final bool disabled;
  final ButtonVariant variant;
  final ButtonSize size;
  final String _textNotNull;

  const AppButton({
    super.key,
    this.text,
    this.icon,
    this.onPressed,
    this.style,
    this.disabled = false,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.md,
  }) : assert(
         variant == ButtonVariant.iconOnly ? icon != null : text != null,
       ),
       _textNotNull = variant != ButtonVariant.iconOnly ? text ?? '' : '';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final custom = CustomTheme.of(context);
    final height = switch (size) {
      ButtonSize.sm => custom.controlHeightSm,
      ButtonSize.md => custom.controlHeightMd,
      ButtonSize.lg => custom.controlHeightLg,
    };
    final iconSize = switch (size) {
      ButtonSize.sm => 12.0,
      ButtonSize.md => 16.0,
      ButtonSize.lg => 20.0,
    };

    final btnStyle = switch (variant) {
      ButtonVariant.primary => _primaryStyle(colors, custom, height),
      ButtonVariant.secondary => _secondaryStyle(colors, custom, height),
      ButtonVariant.text => _textStyle(colors, custom),
      ButtonVariant.iconOnly => _iconOnlyStyle(colors, custom),
    };

    final textButton = TextButton(
      onPressed: disabled ? null : onPressed,
      style: btnStyle
          .merge(
            ButtonStyle(
              mouseCursor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return SystemMouseCursors.basic;
                }
                return SystemMouseCursors.click;
              }),
            ),
          )
          .merge(style),
      child: _buildChild(custom, iconSize),
    );

    return SizedBox(
      width: variant == ButtonVariant.iconOnly ? height : null,
      height: height,
      child: textButton,
    );
  }

  Widget _buildChild(CustomTheme custom, double iconSize) {
    if (variant == ButtonVariant.iconOnly) {
      return Tooltip(
        message: text ?? '',
        child: AppIcon(icon!, size: iconSize),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(icon!, size: iconSize),
          SizedBox(width: custom.spacingSm),
          AppText(_textNotNull),
        ],
      );
    }
    return AppText(_textNotNull);
  }

  ButtonStyle _primaryStyle(
    ColorScheme colors,
    CustomTheme custom,
    double height,
  ) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return colors.primary.withValues(alpha: _kPressedOpacity);
        }
        if (states.contains(WidgetState.hovered)) {
          return colors.primary.withValues(alpha: _kHoverOpacity);
        }
        return colors.primary;
      }),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(vertical: 0, horizontal: custom.spacingMd),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: custom.radiusXs),
      ),
      elevation: WidgetStateProperty.all(1),
      shadowColor: WidgetStateProperty.all(
        colors.onSurface.withValues(alpha: 0.08),
      ),
    );
  }

  ButtonStyle _secondaryStyle(
    ColorScheme colors,
    CustomTheme custom,
    double height,
  ) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return Color.alphaBlend(
            colors.onSurface.withValues(alpha: 0.04),
            colors.surface,
          );
        }
        return colors.surface;
      }),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(vertical: 0, horizontal: custom.spacingMd),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: custom.radiusXs,
          side: BorderSide(color: colors.onSurface.withValues(alpha: 0.08)),
        ),
      ),
      elevation: WidgetStateProperty.all(0),
    );
  }

  ButtonStyle _textStyle(ColorScheme colors, CustomTheme custom) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.all(Colors.transparent),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(
          horizontal: custom.spacingXs,
          vertical: custom.spacingXs,
        ),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: custom.radiusXs),
      ),
      elevation: WidgetStateProperty.all(0),
    );
  }

  ButtonStyle _iconOnlyStyle(ColorScheme colors, CustomTheme custom) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return Color.alphaBlend(
            colors.onSurface.withValues(alpha: 0.04),
            colors.surface,
          );
        }
        return Colors.transparent;
      }),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      padding: WidgetStateProperty.all(EdgeInsets.all(custom.spacingXs)),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: custom.radiusSm),
      ),
      elevation: WidgetStateProperty.all(0),
    );
  }
}
