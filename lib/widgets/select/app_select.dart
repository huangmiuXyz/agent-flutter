import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/card/app_card.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/list/app_list.dart';

/// A single option inside [AppSelect].
class AppSelectOption<T> {
  /// The underlying value returned when selected.
  final T value;

  /// Display text.
  final String label;

  /// Optional icon name resolved via [AppIcon].
  final String? icon;

  /// Whether this item can be selected. Defaults to `true`.
  final bool enabled;

  const AppSelectOption({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
  });
}

/// A themed dropdown select built from [AppField], [AppCard], [AppList],
/// and [AppListItem].
class AppSelect<T> extends HookWidget {
  /// Currently selected value.
  final T? value;

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
  final List<AppSelectOption<T>> options;

  /// Called when the user selects an option.
  final ValueChanged<T?>? onChanged;

  /// Maximum height of the dropdown menu.
  final double menuMaxHeight;

  const AppSelect({
    super.key,
    this.value,
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
    final custom = CustomTheme.of(context);
    final isOpen = useState(false);
    final fieldKey = useMemoized(() => GlobalKey());
    final layerLink = useMemoized(() => LayerLink());
    // Capture field width in gesture phase (post-layout) so it's safe to
    // read during the OverlayEntry builder call.
    final fieldWidth = useRef<double?>(null);

    final enabled = !disabled && onChanged != null;

    // Find the label for the current value.
    final selectedLabel = useMemoized(() {
      if (value == null) return null;
      final idx = options.indexWhere((o) => o.value == value);
      return idx >= 0 ? options[idx].label : null;
    }, [value, options]);

    // Open/close dropdown via OverlayEntry with a transparent barrier.
    useEffect(() {
      if (!isOpen.value) return null;

      final dropdownWidth = fieldWidth.value;

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
              offset: Offset(0, custom.spacing.xs),
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: dropdownWidth,
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: menuMaxHeight),
                      child: AppList(
                        size: AppListSize.small,
                        containerPadding: EdgeInsets.all(custom.spacing.xs),
                        children: [
                          for (final option in options)
                            AppListItem(
                              label: option.label,
                              icon: option.icon,
                              active: option.value == value,
                              disabled: !option.enabled || !enabled,
                              labelVariant: AppTextVariant.body,
                              intrinsicHeight: true,
                              onTap: option.enabled && enabled
                                  ? () {
                                      isOpen.value = false;
                                      onChanged?.call(option.value);
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
    }, [isOpen.value]);

    return CompositedTransformTarget(
      link: layerLink,
      child: GestureDetector(
        onTap: enabled
            ? () {
                // Capture the field width after layout (safe in gesture phase).
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
            controller: useMemoized(
              () => selectedLabel != null
                  ? TextEditingController(text: selectedLabel)
                  : null,
              [selectedLabel],
            ),
          ),
        ),
      ),
    );
  }
}
