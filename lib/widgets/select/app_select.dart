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

  /// 分组名：同组选项显示在同一个分组标题下；null = 不分组。
  final String? group;

  const AppSelectOption({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
    this.group,
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

  /// 下拉面板的最大宽度；null（默认）= 跟随输入框宽度，不限制。
  /// 内容超过该宽度时由菜单项以省略号截断显示。
  final double? menuMaxWidth;

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
    this.menuMaxWidth,
  });

  /// Build the dropdown menu items, grouping by [AppSelectOption.group].
  ///
  /// 同一分组名的选项渲染在 [AppListGroup]（带分组标题）下；
  /// `group == null` 的选项平铺渲染。
  List<Widget> _buildMenuItems(
    CustomTheme custom,
    bool enabled,
    ValueChanged<AppSelectOption<T>> onSelect,
  ) {
    final Map<String?, List<AppSelectOption<T>>> groups = {};
    for (final option in options) {
      groups.putIfAbsent(option.group, () => []).add(option);
    }

    final result = <Widget>[];
    for (final entry in groups.entries) {
      final items = [
        for (final option in entry.value)
          AppListItem(
            label: option.label,
            icon: option.icon,
            labelMaxLines: 1,
            active: option.value == value,
            disabled: !option.enabled || !enabled,
            labelVariant: AppTextVariant.body,
            intrinsicHeight: true,
            onTap: option.enabled && enabled
                ? () => onSelect(option)
                : null,
          ),
      ];
      if (entry.key != null) {
        result.add(
          AppListGroup(
            title: entry.key,
            padding: EdgeInsets.zero,
            itemGap: 0,
            children: items,
          ),
        );
      } else {
        result.addAll(items);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = useState(false);
    final fieldKey = useMemoized(() => GlobalKey());
    final layerLink = useMemoized(() => LayerLink());
    final fieldWidth = useRef<double?>(null);

    final enabled = !disabled && onChanged != null;

    // Find the label for the current value.
    final selectedLabel = useMemoized(() {
      if (value == null) return null;
      final idx = options.indexWhere((o) => o.value == value);
      return idx >= 0 ? options[idx].label : null;
    }, [value, options]);

    final custom = CustomTheme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    // Open/close dropdown via OverlayEntry with a transparent barrier.
    useEffect(() {
      if (!isOpen.value) return null;

      final dropdownWidth = fieldWidth.value;

      // Determine dropdown direction: prefer down if enough space, else up.
      final fieldBox =
          fieldKey.currentContext?.findRenderObject() as RenderBox?;
      final fieldPos = fieldBox?.localToGlobal(Offset.zero);
      final fieldBottom = (fieldPos?.dy ?? 0) + (fieldBox?.size.height ?? 0);
      final spaceBelow = screenHeight - fieldBottom;
      final groupedCount = options
          .where((o) => o.group != null)
          .map((o) => o.group)
          .toSet()
          .length;
      final estimatedMenuHeight =
          (options.length * custom.controls.mediumHeight +
                  groupedCount * custom.controls.smallHeight)
              .clamp(0.0, menuMaxHeight);
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
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: menuMaxWidth ?? double.infinity,
                  ),
                  child: SizedBox(
                    width: dropdownWidth,
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: menuMaxHeight),
                        child: SingleChildScrollView(
                          child: AppList(
                            size: AppListSize.small,
                            containerPadding: EdgeInsets.all(
                              custom.spacing.xs,
                            ),
                            children: _buildMenuItems(
                              custom,
                              enabled,
                              (option) {
                                isOpen.value = false;
                                onChanged?.call(option.value);
                              },
                            ),
                          ),
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
