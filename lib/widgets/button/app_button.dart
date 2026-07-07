import 'package:flutter/material.dart';

import '../../theme/custom_theme.dart';

const _kHoverOpacity = 0.88;
const _kPressedOpacity = 0.82;

enum ButtonVariant { primary, secondary, text, iconOnly }

enum ButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? text;
  final IconData? icon;
  final ButtonStyle? style;
  final bool disabled;
  final ButtonVariant variant;
  final ButtonSize size;

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
         'text is required for primary/secondary/text variants, icon is required for icon variant',
       );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final custom = CustomTheme.of(context);

    final height = _controlHeight(custom);

    final btnStyle = switch (variant) {
      ButtonVariant.primary => _primaryStyle(colors, custom, height),
      ButtonVariant.secondary => _secondaryStyle(colors, custom, height),
      ButtonVariant.text => _textStyle(colors, custom),
      ButtonVariant.iconOnly => _iconOnlyStyle(colors, custom),
    };

    final textButton = TextButton(
      onPressed: disabled ? null : onPressed,
      style: btnStyle.merge(ButtonStyle(
        mouseCursor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return SystemMouseCursors.basic;
          return SystemMouseCursors.click;
        }),
      )).merge(style),
      child: _buildChild(custom),
    );

    if (variant == ButtonVariant.iconOnly) {
      return SizedBox(
        width: height,
        height: height,
        child: textButton,
      );
    }
    return SizedBox(
      height: height,
      child: textButton,
    );
  }

  double _controlHeight(CustomTheme custom) {
    return switch (size) {
      ButtonSize.sm => custom.controlHeightSm,
      ButtonSize.md => custom.controlHeightMd,
      ButtonSize.lg => custom.controlHeightLg,
    };
  }

  Widget _buildChild(CustomTheme custom) {
    if (variant == ButtonVariant.iconOnly) {
      return Icon(icon, size: custom.fontSizeBody);
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: custom.fontSizeBody),
          SizedBox(width: custom.spacingSm),
          Text(text!),
        ],
      );
    }
    return Text(text!);
  }

  ButtonStyle _primaryStyle(ColorScheme colors, CustomTheme custom, double height) {
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
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return colors.onPrimary.withValues(alpha: _kPressedOpacity);
        }
        if (states.contains(WidgetState.hovered)) {
          return colors.onPrimary.withValues(alpha: _kHoverOpacity);
        }
        return colors.onPrimary;
      }),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(vertical: 0, horizontal: custom.spacingMd),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: custom.radiusXs,
        ),
      ),
      textStyle: WidgetStateProperty.all(
        TextStyle(
          fontSize: custom.fontSizeBody,
          fontFamily: 'NotoSansSC',
        ),
      ),
      elevation: WidgetStateProperty.all(1),
      shadowColor: WidgetStateProperty.all(colors.onSurface.withValues(alpha: 0.08)),
    );
  }

  ButtonStyle _secondaryStyle(ColorScheme colors, CustomTheme custom, double height) {
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
      foregroundColor: WidgetStateProperty.all(colors.onSurface),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(vertical: 0, horizontal: custom.spacingMd),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: custom.radiusXs,
          side: BorderSide(
            color: colors.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      textStyle: WidgetStateProperty.all(
        TextStyle(
          fontSize: custom.fontSizeBody,
          fontFamily: 'NotoSansSC',
        ),
      ),
      elevation: WidgetStateProperty.all(0),
    );
  }

  ButtonStyle _textStyle(ColorScheme colors, CustomTheme custom) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.all(Colors.transparent),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return colors.onSurface;
        }
        return colors.onSurfaceVariant;
      }),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(horizontal: custom.spacingXs, vertical: custom.spacingXs),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: custom.radiusXs,
        ),
      ),
      textStyle: WidgetStateProperty.all(
        TextStyle(
          fontSize: custom.fontSizeBody,
          fontWeight: FontWeight.w600,
          fontFamily: 'NotoSansSC',
        ),
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
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return colors.onSurface;
        }
        return colors.onSurfaceVariant;
      }),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      padding: WidgetStateProperty.all(EdgeInsets.all(custom.spacingXs)),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: custom.radiusSm,
        ),
      ),
      elevation: WidgetStateProperty.all(0),
    );
  }
}
