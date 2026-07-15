import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Controls the visual size of [AppSwitch].
enum SwitchSize { sm, md, lg }

class AppSwitch extends HookWidget {
  /// The current state of the switch.
  final bool value;

  /// Called when the user toggles the switch.
  ///
  /// When `null`, the switch behaves as read-only but remains visually
  /// interactive (cursor changes). Combine with [disabled] for a fully
  /// disabled appearance.
  final ValueChanged<bool>? onChanged;

  /// Whether the switch is disabled.
  ///
  /// When `true`, the switch appears dimmed and cannot be toggled.
  /// Defaults to `false`.
  final bool disabled;

  /// Optional label displayed to the right of the switch.
  final String? label;

  /// The size of the switch.
  ///
  /// Defaults to [SwitchSize.md].
  final SwitchSize size;

  const AppSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.disabled = false,
    this.label,
    this.size = SwitchSize.md,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final isHovered = useState(false);
    final isDisabled = disabled || onChanged == null;

    // ---- Sizing ----------------------------------------------------------
    // Switch dimensions are defined as dedicated tokens in [AppControls] —
    // no expression-based arithmetic.
    final (double trackHeight, double trackWidth) = switch (size) {
      SwitchSize.sm => (custom.controls.switchSmHeight, custom.controls.switchSmWidth),
      SwitchSize.md => (custom.controls.switchMdHeight, custom.controls.switchMdWidth),
      SwitchSize.lg => (custom.controls.switchLgHeight, custom.controls.switchLgWidth),
    };
    // Thumb is slightly smaller than the track, with xs (4px) total air gap
    final thumbSize = trackHeight - custom.spacing.xs;
    final thumbInset = (trackHeight - thumbSize) / 2;
    final thumbOnLeft = trackWidth - thumbSize - thumbInset;

    // ---- Colors & border -------------------------------------------------
    final Color trackColor;
    final Color thumbColor;
    final Color? trackBorderColor;

    if (isDisabled) {
      trackColor = custom.colors.panel;
      thumbColor = custom.colors.textDisabled;
      trackBorderColor = null;
    } else if (value) {
      trackColor = isHovered.value ? custom.colors.accentHover : custom.colors.accent;
      thumbColor = custom.colors.onAccent;
      trackBorderColor = null;
    } else {
      trackColor = isHovered.value ? custom.colors.hover : custom.colors.panel;
      thumbColor = custom.colors.textPrimary;
      trackBorderColor = isHovered.value ? custom.colors.border : custom.colors.borderSubtle;
    }

    // ---- Switch widget ---------------------------------------------------
    final switchWidget = SizedBox(
      width: trackWidth,
      height: trackHeight,
      child: GestureDetector(
        onTap: isDisabled ? null : () => onChanged?.call(!value),
        child: MouseRegion(
          onEnter: (_) => isHovered.value = true,
          onExit: (_) => isHovered.value = false,
          cursor: isDisabled
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: trackWidth,
            height: trackHeight,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(trackHeight / 2),
              border: trackBorderColor != null
                  ? Border.all(color: trackBorderColor)
                  : null,
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  left: value ? thumbOnLeft : thumbInset,
                  top: thumbInset,
                  bottom: thumbInset,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: thumbSize,
                    decoration: BoxDecoration(
                      color: thumbColor,
                      shape: BoxShape.circle,
                      boxShadow: custom.shadows.small,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // ---- With label ------------------------------------------------------
    if (label != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          switchWidget,
          SizedBox(width: custom.spacing.sm),
          GestureDetector(
            onTap: isDisabled ? null : () => onChanged?.call(!value),
            child: AppText(
              label!,
              variant: AppTextVariant.body,
              color: isDisabled
                  ? custom.colors.textDisabled
                  : custom.colors.textPrimary,
            ),
          ),
        ],
      );
    }

    return switchWidget;
  }
}
