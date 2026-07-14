import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Size variants for [AppField].
enum FieldSize { sm, md, lg }

/// A reusable text input widget styled with the app's custom theme tokens.
///
/// Supports three sizes via [size]:
/// - [FieldSize.sm] — compact (24px height)
/// - [FieldSize.md] — default (32px height)
/// - [FieldSize.lg] — spacious (40px height)
class AppField extends HookWidget {
  final String? placeholder;
  final String? label;
  final String? icon;
  final String? suffixIcon;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final String? errorText;
  final FieldSize size;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final int? maxLines;
  final int? minLines;

  const AppField({
    super.key,
    this.placeholder,
    this.label,
    this.icon,
    this.suffixIcon,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.errorText,
    this.size = FieldSize.md,
    this.keyboardType,
    this.textInputAction,
    this.focusNode,
    this.maxLines = 1,
    this.minLines,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final physicalPixel = 1 / MediaQuery.devicePixelRatioOf(context);
    final isHovered = useState(false);
    final isFocused = useState(false);

    final height = switch (size) {
      FieldSize.sm => custom.controls.smallHeight,
      FieldSize.md => custom.controls.mediumHeight,
      FieldSize.lg => custom.controls.largeHeight,
    };

    final fontSize = switch (size) {
      FieldSize.sm => custom.typography.captionSize,
      FieldSize.md => custom.typography.bodySize,
      FieldSize.lg => custom.typography.subtitleSize,
    };

    final iconSize = switch (size) {
      FieldSize.sm => custom.typography.captionSize,
      FieldSize.md => custom.typography.subtitleSize,
      FieldSize.lg => custom.typography.titleSize,
    };

    final borderRadius = switch (size) {
      FieldSize.sm || FieldSize.md => custom.radii.xs,
      FieldSize.lg => custom.radii.sm,
    };

    final horizontalPadding = switch (size) {
      FieldSize.sm || FieldSize.md => custom.spacing.sm,
      FieldSize.lg => custom.spacing.md,
    };

    final hasError = errorText != null && errorText!.isNotEmpty;
    final isDisabled = !enabled;
    final isSingleLine = maxLines == 1;

    final focusColor = hasError ? custom.colors.danger : custom.colors.accent;
    final borderColor = hasError
        ? custom.colors.danger
        : isFocused.value
        ? custom.colors.accent.withValues(alpha: 0.72)
        : isHovered.value
        ? custom.colors.border
        : custom.colors.borderSubtle;

    final bgColor = isDisabled ? custom.colors.panel : custom.colors.background;

    final input = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null)
          Padding(
            padding: EdgeInsets.only(left: horizontalPadding),
            child: AppIcon(
              icon!,
              size: iconSize,
              color: hasError
                  ? custom.colors.danger
                  : isDisabled
                  ? custom.colors.textDisabled
                  : custom.colors.textSecondary,
            ),
          ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              obscureText: obscureText,
              enabled: enabled,
              readOnly: readOnly,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              maxLines: maxLines,
              minLines: minLines,
              style: custom.typography.styleForSize(
                fontSize,
                isDisabled
                    ? custom.colors.textDisabled
                    : custom.colors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: custom.typography.styleForSize(
                  fontSize,
                  custom.colors.textDisabled,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        if (suffixIcon != null)
          Padding(
            padding: EdgeInsets.only(right: horizontalPadding),
            child: AppIcon(
              suffixIcon!,
              size: iconSize,
              color: isDisabled
                  ? custom.colors.textDisabled
                  : custom.colors.textSecondary,
            ),
          ),
      ],
    );

    final inputContainer = Container(
      constraints: isSingleLine
          ? BoxConstraints.tightFor(height: height)
          : BoxConstraints(minHeight: height),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: physicalPixel),
        boxShadow: enabled && isFocused.value
            ? [
                BoxShadow(
                  color: focusColor.withValues(alpha: 0.12),
                  blurRadius: 2,
                  spreadRadius: physicalPixel,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: input,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Padding(
            padding: EdgeInsets.only(bottom: custom.spacing.xs),
            child: AppText(
              label!,
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
            ),
          ),
        ],
        MouseRegion(
          onEnter: (_) => isHovered.value = true,
          onExit: (_) => isHovered.value = false,
          child: Focus(
            onFocusChange: (focused) => isFocused.value = focused,
            child: inputContainer,
          ),
        ),
        if (hasError) ...[
          Padding(
            padding: EdgeInsets.only(top: custom.spacing.xs),
            child: AppText(
              errorText!,
              variant: AppTextVariant.caption,
              color: custom.colors.danger,
            ),
          ),
        ],
      ],
    );
  }
}
