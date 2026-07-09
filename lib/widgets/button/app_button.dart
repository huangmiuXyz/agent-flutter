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
    final custom = CustomTheme.of(context);
    final isHovered = useState(false);
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

    final textColor = switch (variant) {
      ButtonVariant.primary => custom.onPrimary,
      ButtonVariant.text => isHovered.value ? custom.primary : custom.onSurfaceVariant,
      _ => null,
    };

    final btnStyle = switch (variant) {
      ButtonVariant.primary => _primaryStyle(custom, height),
      ButtonVariant.secondary => _secondaryStyle(custom, height),
      ButtonVariant.text => _textStyle(custom),
      ButtonVariant.iconOnly => _iconOnlyStyle(custom),
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
            : variant == ButtonVariant.text
                ? Size.zero
                : Size(0, height),
      ),
      maximumSize: WidgetStateProperty.all(
        variant == ButtonVariant.iconOnly
            ? Size(height, height)
            : variant == ButtonVariant.text
                ? Size.infinite
                : Size(double.infinity, height),
      ),
    );

    final textButton = TextButton(
      onPressed: disabled ? null : onPressed,
      style: btnStyle.merge(sizeStyle).merge(style),
      child: _buildChild(
        custom,
        iconSize,
        textColor,
      ),
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
    return UnconstrainedBox(
      child: SizedBox(height: height, child: textButton),
    );
  }

  Widget _buildChild(CustomTheme custom, double iconSize, Color? textColor) {
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
          AppText(_textNotNull, color: textColor),
        ],
      );
    }
    return AppText(_textNotNull, color: textColor);
  }

  ButtonStyle _primaryStyle(CustomTheme custom, double height) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return custom.primaryContainer;
        }
        if (states.contains(WidgetState.pressed)) {
          return custom.surfaceContainerHighest;
        }
        return custom.primary;
      }),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(vertical: 0, horizontal: custom.spacingMd),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: custom.radiusXs),
      ),
      elevation: WidgetStateProperty.all(2),
    );
  }

  ButtonStyle _secondaryStyle(CustomTheme custom, double height) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return custom.surfaceContainerLow;
        }
        return custom.surface;
      }),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(vertical: 0, horizontal: custom.spacingMd),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: custom.radiusXs,
          side: BorderSide(color: custom.outlineVariant),
        ),
      ),
      elevation: WidgetStateProperty.all(1),
    );
  }

  ButtonStyle _textStyle(CustomTheme custom) {
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

  ButtonStyle _iconOnlyStyle(CustomTheme custom) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return custom.surfaceContainer;
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
