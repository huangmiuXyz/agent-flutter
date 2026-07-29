import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/card/app_card.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/list/app_list.dart';
import 'package:agent/widgets/text/app_text.dart';

/// A single option inside [AppMultiSelect].
class AppMultiSelectOption<T> {
  /// The underlying value.
  final T value;

  /// Display text.
  final String label;

  /// Optional icon name resolved via [AppIcon].
  final String? icon;

  /// Whether this item can be toggled. Defaults to `true`.
  final bool enabled;

  const AppMultiSelectOption({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
  });
}

/// A themed multi-select dropdown built from [AppField], [AppCard],
/// [AppList], and [AppListItem].
///
/// Visually consistent with [AppSelect], but allows multiple items to be
/// toggled on/off. The dropdown stays open after toggling an item and
/// closes on outside tap.
class AppMultiSelect<T> extends HookWidget {
  /// Currently selected values.
  final Set<T> value;

  /// Hint text shown when no value is selected.
  final String? placeholder;

  /// Label displayed above the select field.
  final String? label;

  /// Error text displayed below the select field.
  final String? errorText;

  /// Whether the select is disabled.
  final bool disabled;

  /// The visual size, matching [FieldSize].
  final FieldSize size;

  /// Available options.
  final List<AppMultiSelectOption<T>> options;

  /// Called when the user toggles an option.
  final ValueChanged<Set<T>>? onChanged;

  /// Maximum height of the dropdown menu.
  final double menuMaxHeight;

  const AppMultiSelect({
    super.key,
    this.value = const {},
    this.placeholder,
    this.label,
    this.errorText,
    this.disabled = false,
    this.size = FieldSize.md,
    required this.options,
    this.onChanged,
    this.menuMaxHeight = 300,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = useState(false);
    final fieldKey = useMemoized(() => GlobalKey());
    final layerLink = useMemoized(() => LayerLink());
    final fieldWidth = useRef<double?>(null);

    final enabled = !disabled && onChanged != null;

    // Build display text for the field.
    final displayText = useMemoized(() {
      if (value.isEmpty) return null;
      if (value.length == 1) {
        final idx = options.indexWhere((o) => o.value == value.first);
        return idx >= 0 ? options[idx].label : null;
      }
      return '已选 ${value.length} 项';
    }, [value, options]);

    // Permanent controller — text synced via effect to handle null → text transitions.
    final controller = useMemoized(() => TextEditingController(), []);
    useEffect(() {
      controller.text = displayText ?? '';
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      return null;
    }, [displayText]);

    final custom = CustomTheme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    // Open/close dropdown via OverlayEntry with a transparent barrier.
    // value is in deps so the overlay rebuilds when selection changes.
    useEffect(() {
      if (!isOpen.value) return null;

      final dropdownWidth = fieldWidth.value;

      final fieldBox =
          fieldKey.currentContext?.findRenderObject() as RenderBox?;
      final fieldPos = fieldBox?.localToGlobal(Offset.zero);
      final fieldBottom = (fieldPos?.dy ?? 0) + (fieldBox?.size.height ?? 0);
      final spaceBelow = screenHeight - fieldBottom;
      final estimatedMenuHeight =
          (options.length * custom.controls.mediumHeight).clamp(
            0,
            menuMaxHeight,
          );
      final showAbove = spaceBelow < estimatedMenuHeight;

      late OverlayEntry entry;

      entry = OverlayEntry(
        builder: (_) => Stack(
          children: [
            // Transparent barrier — closes on tap
            GestureDetector(
              onTap: () => isOpen.value = false,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
            // Positioned dropdown menu
            CompositedTransformFollower(
              link: layerLink,
              showWhenUnlinked: false,
              offset: Offset(
                0,
                showAbove ? -custom.spacing.xs : custom.spacing.xs,
              ),
              targetAnchor: showAbove
                  ? Alignment.topLeft
                  : Alignment.bottomLeft,
              followerAnchor: showAbove
                  ? Alignment.bottomLeft
                  : Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: dropdownWidth,
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: menuMaxHeight),
                      child: SingleChildScrollView(
                        child: AppList(
                          size: AppListSize.small,
                          containerPadding: EdgeInsets.all(custom.spacing.xs),
                          children: [
                            for (final option in options)
                              AppListItem(
                                label: option.label,
                                icon: option.icon,
                                active: value.contains(option.value),
                                disabled: !option.enabled || !enabled,
                                labelVariant: AppTextVariant.body,
                                intrinsicHeight: true,
                                // Show a checkmark for selected items
                                trailingWidget: value.contains(option.value)
                                    ? AppIcon(
                                        'check',
                                        size: custom.typography.bodySize,
                                        color: custom.colors.accent,
                                      )
                                    : null,
                                onTap: option.enabled && enabled
                                    ? () {
                                        final newSet = Set<T>.from(value);
                                        if (newSet.contains(option.value)) {
                                          newSet.remove(option.value);
                                        } else {
                                          newSet.add(option.value);
                                        }
                                        onChanged?.call(newSet);
                                        // Don't close — multi-select stays open
                                      }
                                    : null,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isOpen.value) {
          entry.remove();
          return;
        }
        Overlay.of(context).insert(entry);
      });
      return () => entry.remove();
    }, [isOpen.value, value, options, enabled]);

    return CompositedTransformTarget(
      link: layerLink,
      child: GestureDetector(
        onTap: enabled
            ? () {
                fieldWidth.value = fieldKey.currentContext?.size?.width;
                isOpen.value = !isOpen.value;
              }
            : null,
        child: AbsorbPointer(
          child: AppField(
            key: fieldKey,
            label: label,
            placeholder: placeholder ?? '',
            enabled: true,
            readOnly: true,
            errorText: errorText,
            size: size,
            suffixIcon: 'chevronDown',
            controller: controller,
          ),
        ),
      ),
    );
  }
}
