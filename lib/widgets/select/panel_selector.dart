import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/context_menu/context_menu.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';

/// A single option inside [PanelSelector].
class PanelSelectorOption<T> {
  /// The underlying value returned when selected.
  final T value;

  /// Display text.
  final String label;

  /// Optional icon name resolved via [AppIcon].
  final String? icon;

  /// Whether this item can be selected. Defaults to `true`.
  final bool enabled;

  const PanelSelectorOption({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
  });
}

/// A compact panel-style selector with a label + down arrow.
///
/// Tapping opens a [ContextMenu] dropdown; the currently selected item
/// is marked with a checkmark via [MenuItem.selected].
class PanelSelector<T> extends HookWidget {
  /// Currently selected value.
  final T? value;

  /// Hint text shown when no value is selected.
  final String? placeholder;

  /// Available options.
  final List<PanelSelectorOption<T>> options;

  /// Called when the user selects an option.
  final ValueChanged<T?>? onChanged;

  /// Minimum width of the dropdown menu.
  final double menuMinWidth;

  const PanelSelector({
    super.key,
    this.value,
    this.placeholder,
    required this.options,
    this.onChanged,
    this.menuMinWidth = 160,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final isHovered = useState(false);
    final buttonKey = useMemoized(() => GlobalKey());

    final enabled = onChanged != null;

    // Find the label for the current value.
    final selectedLabel = useMemoized(() {
      if (value == null) return null;
      final idx = options.indexWhere((o) => o.value == value);
      return idx >= 0 ? options[idx].label : null;
    }, [value, options]);

    void onTap() {
      // Get the button's global position to anchor the menu.
      final renderBox =
          buttonKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;

      final position = renderBox.localToGlobal(Offset.zero);
      final buttonSize = renderBox.size;

      // Place the menu below the button, left-aligned.
      final menuPosition = Offset(
        position.dx,
        position.dy + buttonSize.height + custom.spacing.xs,
      );

      ContextMenu.show(
        context,
        position: menuPosition,
        minWidth: menuMinWidth,
        items: [
          for (final option in options)
            MenuItem(
              label: option.label,
              icon: option.icon,
              enabled: option.enabled && enabled,
              selected: option.value == value,
              onTap: () {
                onChanged?.call(option.value);
              },
            ),
        ],
      );
    }

    return MouseRegion(
      onEnter: (_) => isHovered.value = true,
      onExit: (_) => isHovered.value = false,
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          key: buttonKey,
          height: custom.controls.smallHeight,
          padding: EdgeInsets.symmetric(horizontal: custom.spacing.sm),
          decoration: BoxDecoration(
            color: isHovered.value ? custom.colors.hover : Colors.transparent,
            borderRadius: custom.radii.xs,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  selectedLabel ?? placeholder ?? '',
                  variant: AppTextVariant.caption,
                  color: selectedLabel != null
                      ? custom.colors.textPrimary
                      : custom.colors.textSecondary,
                ),
                SizedBox(width: custom.spacing.xs),
                AppIcon(
                  'chevronDown',
                  size: custom.typography.captionSize,
                  color: custom.colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
