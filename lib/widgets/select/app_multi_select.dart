import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/card/app_card.dart';
import 'package:agent/widgets/divider/app_divider.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/list/app_list.dart';

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

  /// 是否在下拉面板顶部显示搜索框，实时过滤选项。
  ///
  /// 搜索框聚焦时：输入即过滤（匹配选项名），↑/↓ 移动选中，
  /// Enter 确认选中，Esc 关闭面板。默认 true。
  final bool searchable;

  /// 搜索框占位提示；仅 [searchable] 为 true 时使用。null = 「搜索…」。
  final String? searchHint;

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
    this.searchable = true,
    this.searchHint,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = useState(false);
    final fieldKey = useMemoized(() => GlobalKey());
    final layerLink = useMemoized(() => LayerLink());
    final fieldWidth = useRef<double?>(null);

    final enabled = !disabled && onChanged != null;

    // 搜索状态：查询文本 + 输入框控制器/焦点
    final searchQuery = useState('');
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();
    // 菜单内容版本：选中值/选项变化时原地刷新菜单（不重建 OverlayEntry，
    // 否则勾选一项后搜索框会丢失焦点）
    final contentVersion = useMemoized(() => ValueNotifier(0));
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        contentVersion.value++;
      });
      return null;
    }, [value, options]);

    // 最新 value/options/enabled 引用：菜单打开期间内容变化时，
    // 由 OverlayEntry 内的 ListenableBuilder 读取（闭包捕获的旧值不会更新）。
    final valueRef = useRef(value);
    valueRef.value = value;
    final optionsRef = useRef(options);
    optionsRef.value = options;
    final enabledRef = useRef(enabled);
    enabledRef.value = enabled;

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

    // 面板顶部搜索条：输入实时过滤（匹配选项名），Esc 关闭面板
    Widget buildSearchHeader() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              custom.spacing.sm,
              custom.spacing.xs,
              custom.spacing.sm,
              custom.spacing.xs,
            ),
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  isOpen.value = false;
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Row(
                children: [
                  AppIcon(
                    'search',
                    size: custom.typography.captionSize,
                    color: custom.colors.textSecondary,
                  ),
                  SizedBox(width: custom.spacing.xs),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      focusNode: searchFocusNode,
                      onChanged: (v) => searchQuery.value = v,
                      style: TextStyle(
                        fontSize: custom.typography.captionSize,
                        fontFamily: custom.typography.fontFamily,
                        color: custom.colors.textPrimary,
                      ),
                      cursorColor: custom.colors.textPrimary,
                      decoration: InputDecoration(
                        hintText: searchHint ?? '搜索…',
                        hintStyle: TextStyle(
                          fontSize: custom.typography.captionSize,
                          color: custom.colors.textSecondary,
                        ),
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppDivider(size: AppDividerSize.small),
        ],
      );
    }

    // Open/close dropdown via OverlayEntry with a transparent barrier.
    // 菜单内容由 ListenableBuilder 监听搜索词/内容版本原地刷新：
    // 勾选选项不重建 OverlayEntry，搜索框焦点得以保持。
    useEffect(() {
      if (!isOpen.value) return null;

      final dropdownWidth = fieldWidth.value;

      final fieldBox =
          fieldKey.currentContext?.findRenderObject() as RenderBox?;
      final fieldPos = fieldBox?.localToGlobal(Offset.zero);
      final fieldBottom = (fieldPos?.dy ?? 0) + (fieldBox?.size.height ?? 0);
      final spaceBelow = screenHeight - fieldBottom;
      final estimatedMenuHeight =
          (optionsRef.value.length * custom.controls.mediumHeight).clamp(
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
                      child: ListenableBuilder(
                        listenable: Listenable.merge(
                          [searchQuery, contentVersion],
                        ),
                        builder: (context, _) {
                          final currentValue = valueRef.value;
                          final currentOptions = optionsRef.value;
                          final currentEnabled = enabledRef.value;
                          final query =
                              searchQuery.value.trim().toLowerCase();
                          bool matches(AppMultiSelectOption<T> o) =>
                              query.isEmpty ||
                              o.label.toLowerCase().contains(query);
                          final visible = searchable
                              ? currentOptions.where(matches).toList()
                              : currentOptions;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (searchable) buildSearchHeader(),
                              Flexible(
                                child: SingleChildScrollView(
                                  child: AppList(
                                    size: AppListSize.small,
                                    containerPadding: EdgeInsets.all(
                                      custom.spacing.xs,
                                    ),
                                    keyboardNavigable: searchable,
                                    initialFocusedIndex: searchable ? 0 : -1,
                                    emptyPlaceholder: searchable
                                        ? '无匹配项'
                                        : null,
                                    children: [
                                      for (final option in visible)
                                        AppListItem(
                                          label: option.label,
                                          icon: option.icon,
                                          active: currentValue.contains(
                                            option.value,
                                          ),
                                          disabled: !option.enabled ||
                                              !currentEnabled,
                                          labelVariant: AppTextVariant.body,
                                          intrinsicHeight: true,
                                          // Show a checkmark for selected items
                                          trailingWidget: currentValue
                                                  .contains(option.value)
                                              ? AppIcon(
                                                  'check',
                                                  size: custom
                                                      .typography.bodySize,
                                                  color: custom.colors.accent,
                                                )
                                              : null,
                                          onTap: option.enabled &&
                                                  currentEnabled
                                              ? () {
                                                  final newSet = Set<T>.from(
                                                    currentValue,
                                                  );
                                                  if (newSet.contains(
                                                    option.value,
                                                  )) {
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
                            ],
                          );
                        },
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
        if (searchable) {
          // 菜单挂载完成后再聚焦搜索框（post-frame 嵌套，等下一帧渲染）
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!isOpen.value) return;
            searchFocusNode.requestFocus();
          });
        }
      });
      return () => entry.remove();
    }, [isOpen.value]);

    return CompositedTransformTarget(
      link: layerLink,
      child: GestureDetector(
        onTap: enabled
            ? () {
                fieldWidth.value = fieldKey.currentContext?.size?.width;
                // 打开时重置搜索：每次打开从空搜索开始
                if (!isOpen.value) {
                  searchController.clear();
                  searchQuery.value = '';
                }
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
