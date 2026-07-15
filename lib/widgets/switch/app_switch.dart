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
    // Switch track height is intentionally more compact than button heights.
    // Derived from spacing tokens to keep switches visually lightweight.
    final trackHeight = switch (size) {
      SwitchSize.sm => custom.spacing.md,                          // 16
      SwitchSize.md => custom.spacing.md + custom.spacing.xs,      // 20
      SwitchSize.lg => custom.spacing.lg,                          // 24
    };
    final trackWidth = trackHeight * 1.75;
    // Thumb is slightly smaller than the track, with xs (4px) total air gap
    final thumbSize = trackHeight - custom.spacing.xs;
    final thumbInset = (trackHeight - thumbSize) / 2;
    final thumbOnLeft = trackWidth - thumbSize - thumbInset;

    // ---- Colors ----------------------------------------------------------
    final effectiveTrackColor = isDisabled
        ? custom.colors.panel
        : value
            ? (isHovered.value ? custom.colors.accentHover : custom.colors.accent)
            : (isHovered.value ? custom.colors.hover : custom.colors.panelElevated);

    final effectiveThumbColor = isDisabled
        ? custom.colors.textDisabled
        : value
            ? custom.colors.onAccent
            : custom.colors.textPrimary;

    // ---- Switch widget ---------------------------------------------------
    final switchWidget = GestureDetector(
      onTap: isDisabled ? null : () => onChanged?.call(!value),
      child: MouseRegion(
        onEnter: (_) => isHovered.value = true,
        onExit: (_) => isHovered.value = false,
        cursor:
            isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: trackWidth,
          height: trackHeight,
          decoration: BoxDecoration(
            color: effectiveTrackColor,
            borderRadius: BorderRadius.circular(trackHeight / 2),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                left: value ? thumbOnLeft : thumbInset,
                top: thumbInset,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: thumbSize,
                  height: thumbSize,
                  decoration: BoxDecoration(
                    color: effectiveThumbColor,
                    shape: BoxShape.circle,
                    boxShadow: value ? custom.shadows.small : null,
                  ),
                ),
              ),
            ],
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
