import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';

enum ButtonVariant { primary, secondary, text, iconOnly }

enum ButtonSize { sm, md, lg }

class AppButton extends HookWidget {
  final VoidCallback? onPressed;
  final String? text;
  final String? icon;
  final ButtonStyle? style;
  final bool disabled;
  final bool hoverStyle;
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
    this.hoverStyle = true,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.md,
  }) : assert(variant == ButtonVariant.iconOnly ? icon != null : text != null),
       _textNotNull = variant != ButtonVariant.iconOnly ? text ?? '' : '';

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final isHovered = useState(false);
    final height = switch (size) {
      ButtonSize.sm => custom.controlHeightSm,
      ButtonSize.md => custom.controlHeightMd,
      ButtonSize.lg => custom.controlHeightLg,
    };
    final borderRadius = switch (size) {
      ButtonSize.sm => custom.radiusXs,
      ButtonSize.md => custom.radiusXs,
      ButtonSize.lg => custom.radiusSm,
    };
    final iconSize = switch (size) {
      ButtonSize.sm => custom.fontSizeCaption,
      ButtonSize.md => custom.fontSizeSubtitle,
      ButtonSize.lg => custom.fontSizeTitle,
    };
    final usesContentHeight =
        size == ButtonSize.sm && variant != ButtonVariant.iconOnly;

    final isDisabled = disabled || onPressed == null;
    final textColor = isDisabled
        ? custom.colors.textDisabled
        : switch (variant) {
            ButtonVariant.primary => custom.colors.onAccent,
            ButtonVariant.text =>
              hoverStyle && isHovered.value
                  ? custom.colors.accent
                  : custom.colors.textSecondary,
            ButtonVariant.secondary ||
            ButtonVariant.iconOnly => custom.colors.textPrimary,
          };

    final btnStyle = switch (variant) {
      ButtonVariant.primary => _primaryStyle(custom, height, borderRadius),
      ButtonVariant.secondary => _secondaryStyle(custom, height, borderRadius),
      ButtonVariant.text => _textStyle(custom, borderRadius),
      ButtonVariant.iconOnly => _iconOnlyStyle(custom, borderRadius),
    };

    final sizeStyle = ButtonStyle(
      mouseCursor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return SystemMouseCursors.basic;
        }
        return SystemMouseCursors.click;
      }),
      minimumSize: WidgetStateProperty.all(
        variant == ButtonVariant.iconOnly
            ? Size(height, height)
            : variant == ButtonVariant.text || usesContentHeight
            ? Size.zero
            : Size(0, height),
      ),
      maximumSize: WidgetStateProperty.all(
        variant == ButtonVariant.iconOnly
            ? Size(height, height)
            : variant == ButtonVariant.text || usesContentHeight
            ? Size.infinite
            : Size(double.infinity, height),
      ),
      tapTargetSize: usesContentHeight
          ? MaterialTapTargetSize.shrinkWrap
          : null,
    );

    final textButton = TextButton(
      onPressed: isDisabled ? null : onPressed,
      style: btnStyle.merge(sizeStyle).merge(style),
      child: _buildChild(custom, iconSize, textColor),
    );

    if (variant == ButtonVariant.iconOnly) {
      return UnconstrainedBox(
        child: SizedBox(width: height, height: height, child: textButton),
      );
    }
    if (variant == ButtonVariant.text) {
      return UnconstrainedBox(
        alignment: Alignment.centerLeft,
        child: MouseRegion(
          onEnter: (_) => isHovered.value = true,
          onExit: (_) => isHovered.value = false,
          child: textButton,
        ),
      );
    }
    if (usesContentHeight) {
      return UnconstrainedBox(child: textButton);
    }
    return UnconstrainedBox(
      child: SizedBox(height: height, child: textButton),
    );
  }

  Widget _buildChild(CustomTheme custom, double iconSize, Color? textColor) {
    if (variant == ButtonVariant.iconOnly) {
      return Tooltip(
        message: text ?? '',
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
        child: AppIcon(icon!, size: iconSize, color: textColor),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(icon!, size: iconSize, color: textColor),
          SizedBox(width: custom.spacingSm),
          AppText(_textNotNull, color: textColor),
        ],
      );
    }
    return AppText(_textNotNull, color: textColor);
  }

  ButtonStyle _primaryStyle(
    CustomTheme custom,
    double height,
    BorderRadius borderRadius,
  ) {
    if (!hoverStyle) {
      return ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return custom.colors.panelElevated;
          }
          return custom.colors.accent;
        }),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        padding: WidgetStateProperty.all(
          EdgeInsets.symmetric(vertical: 0, horizontal: custom.spacingMd),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: borderRadius),
        ),
        elevation: WidgetStateProperty.all(2),
      );
    }
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return custom.colors.panelElevated;
        }
        if (states.contains(WidgetState.pressed)) {
          return custom.colors.selected;
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return custom.colors.accentHover;
        }
        return custom.colors.accent;
      }),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(vertical: 0, horizontal: custom.spacingMd),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      elevation: WidgetStateProperty.all(2),
    );
  }

  ButtonStyle _secondaryStyle(
    CustomTheme custom,
    double height,
    BorderRadius borderRadius,
  ) {
    if (!hoverStyle) {
      return ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return custom.colors.panel;
          }
          return custom.colors.background;
        }),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        padding: WidgetStateProperty.all(
          EdgeInsets.symmetric(vertical: 0, horizontal: custom.spacingMd),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(color: custom.colors.borderSubtle),
          ),
        ),
        elevation: WidgetStateProperty.all(1),
      );
    }
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return custom.colors.panel;
        }
        if (states.contains(WidgetState.pressed)) {
          return custom.colors.selected;
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return custom.colors.hover;
        }
        return custom.colors.background;
      }),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(vertical: 0, horizontal: custom.spacingMd),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: custom.colors.borderSubtle),
        ),
      ),
      elevation: WidgetStateProperty.all(1),
    );
  }

  ButtonStyle _textStyle(CustomTheme custom, BorderRadius borderRadius) {
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
        RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      elevation: WidgetStateProperty.all(0),
    );
  }

  ButtonStyle _iconOnlyStyle(CustomTheme custom, BorderRadius borderRadius) {
    if (!hoverStyle) {
      return ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        padding: WidgetStateProperty.all(EdgeInsets.all(custom.spacingXs)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: borderRadius),
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
      padding: WidgetStateProperty.all(EdgeInsets.all(custom.spacingXs)),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      elevation: WidgetStateProperty.all(0),
    );
  }
}
