import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/context_menu/context_menu.dart';
import 'package:agent/widgets/divider/app_divider.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';

/// A single option inside [PanelSelector].
class PanelSelectorOption<T> {
  /// The underlying value returned when selected.
  final T value;

  /// Display text.
  final String label;

  /// 按钮（选中态）显示的文本；null 时回退用 [label]。
  /// 仅影响按钮上展示的选中文本，不影响下拉菜单项。
  final String? displayLabel;

  /// Optional icon name resolved via [AppIcon].
  final String? icon;

  /// Whether this item can be selected. Defaults to `true`.
  final bool enabled;

  /// 悬停时行尾浮出的图标（仅鼠标 hover 时显示）。
  final String? hoverIcon;

  /// 点击 [hoverIcon] 按钮时的回调（不触发行本身的选中）。
  final VoidCallback? onHoverTap;

  const PanelSelectorOption({
    required this.value,
    required this.label,
    this.displayLabel,
    this.icon,
    this.enabled = true,
    this.hoverIcon,
    this.onHoverTap,
  });
}
// ───────────────────────────────────────────────────────────────────────────────

/// A compact panel-style selector with a label + down arrow.
///
/// Tapping opens a [ContextMenu] dropdown; the currently selected item
/// is marked with a checkmark via [MenuItem.selected]. Tapping again while
/// the menu is open collapses it. The chevron icon flips with open state.
///
/// When [data] is provided, each map can contain:
/// - `label` (String) — display text
/// - `value` (T) — value returned when selected
/// - `icon` (String?) — optional icon
/// - `group` (String?) — group header label; items sharing the same
///   [group] are shown under a bold header with separators between groups
/// - `disabled` (bool, default false)
class PanelSelector<T> extends HookWidget {
  /// Currently selected value.
  final T? value;

  /// Hint text shown when no value is selected.
  final String? placeholder;

  /// Flat option list (used when [data] is null).
  final List<PanelSelectorOption<T>> options;

  /// Data-driven mode — raw items from JSON.
  ///
  /// Each item is displayed as:
  /// - `item['label'] ?? item['name'] ?? item.toString()` if it's a Map
  /// - `item.toString()` otherwise
  ///
  /// The selected value returned via [onChanged] is the raw item itself.
  /// When [data] is non-null, [options] is ignored.
  final List<dynamic>? data;

  /// Called when the user selects an option.
  final ValueChanged<T?>? onChanged;

  /// 打开菜单前回调（如刷新数据）。再次点击收起时不触发。
  final VoidCallback? onBeforeOpen;

  /// Minimum width of the dropdown menu.
  final double menuMinWidth;

  /// 下拉面板的最大宽度；null（默认）= 不限制。
  /// 内容超过该宽度时由菜单项以省略号截断显示。
  final double? menuMaxWidth;

  /// 是否拉满父级宽度并将内容左对齐（表单场景用，与输入框对齐）；
  /// 默认 false：内容宽度 + 居中（工具栏按钮风格）。
  final bool fullWidth;

  /// 按钮最大宽度；null = 不限制（内容多宽按钮多宽）。
  /// 超过时选中文本以省略号截断。
  final double? maxWidth;

  /// 按钮上选中文本左侧的前置图标（如推理强度选择器的灯泡）；null = 不显示。
  final String? buttonIcon;

  /// 是否在下拉面板顶部显示搜索框，实时过滤选项。
  ///
  /// 搜索框聚焦时：输入即过滤（匹配选项名与分组名），↑/↓ 移动选中，
  /// Enter 确认选中，Esc 关闭面板。默认 false。
  final bool searchable;

  /// 搜索框占位提示；仅 [searchable] 为 true 时使用。null = 「搜索…」。
  final String? searchHint;

  const PanelSelector({
    super.key,
    this.value,
    this.placeholder,
    this.options = const [],
    this.data,
    this.onChanged,
    this.onBeforeOpen,
    this.menuMinWidth = 160,
    this.menuMaxWidth,
    this.fullWidth = false,
    this.maxWidth,
    this.buttonIcon,
    this.searchable = false,
    this.searchHint,
  });

  /// All flat options extracted from [data] (ignoring group info).
  List<PanelSelectorOption<T>> get _allOptions {
    if (data != null) {
      return data!.map((item) {
        final label = item is Map
            ? (item['label'] as String? ??
                  item['name'] as String? ??
                  item.toString())
            : item.toString();
        final val = item is Map
            ? ((item['value'] as T?) ?? (item['name'] as T?) ?? item as T)
            : item as T;
        return PanelSelectorOption<T>(
          value: val,
          label: label,
          displayLabel: item is Map ? item['displayLabel'] as String? : null,
          icon: item is Map ? item['icon'] as String? : null,
          hoverIcon: item is Map ? item['hoverIcon'] as String? : null,
          onHoverTap: item is Map ? item['onHoverTap'] as VoidCallback? : null,
        );
      }).toList();
    }
    return options;
  }

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final isHovered = useState(false);
    // 本按钮的菜单是否展开（驱动 chevron 图标切换）
    final isOpen = useState(false);
    final buttonKey = useMemoized(() => GlobalKey());
    final layerLink = useMemoized(() => LayerLink());

    final enabled = onChanged != null;

    // 搜索状态（searchable 时启用）：查询文本 + 输入框控制器/焦点
    final searchQuery = useState('');
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();

    // Memoize options so they don't recreate on every build.
    final allOptions = useMemoized(() => _allOptions, [data, options]);

    // 找出当前选中值的显示文本（优先 displayLabel，用于按钮上展示）
    final selectedLabel = useMemoized(() {
      if (value == null) return null;
      final idx = allOptions.indexWhere((o) => o.value == value);
      if (idx < 0) return null;
      return allOptions[idx].displayLabel ?? allOptions[idx].label;
    }, [value, allOptions]);

    // 上次打开菜单时的位置，用于原地刷新
    final lastPosition = useRef<Offset?>(null);
    final lastAlignRight = useRef<bool>(false);

    /// 关闭菜单并复位本地状态（搜索框 Esc、再次点击收起共用）。
    void dismissMenu() {
      isOpen.value = false;
      lastPosition.value = null;
      ContextMenu.dismiss();
    }

    // 搜索过滤：匹配选项名 / 显示名 / 分组名（提供商），大小写不敏感
    final query = searchQuery.value.trim().toLowerCase();
    bool matchesSearch(String? label, String? displayLabel, String? group) {
      if (query.isEmpty) return true;
      return (label != null && label.toLowerCase().contains(query)) ||
          (displayLabel != null && displayLabel.toLowerCase().contains(query)) ||
          (group != null && group.toLowerCase().contains(query));
    }

    /// Build the menu items list, grouping by the `group` key.
    List<MenuItem> buildMenuItems() {
      if (data != null) {
        final result = <MenuItem>[];
        final currentVal = value;

        // Group items by 'group' key
        final Map<String?, List<dynamic>> groups = {};
        for (final item in data!) {
          final g = item is Map ? item['group'] as String? : null;
          groups.putIfAbsent(g, () => []).add(item);
        }

        bool firstGroup = true;
        for (final entry in groups.entries) {
          // 搜索时跳过无匹配项的分组（连同其分组标题/分隔线）
          final matched = entry.value.where((item) {
            final label = item is Map
                ? (item['label'] as String? ??
                      item['name'] as String? ??
                      item.toString())
                : item.toString();
            final displayLabel =
                item is Map ? item['displayLabel'] as String? : null;
            return matchesSearch(label, displayLabel, entry.key);
          }).toList();
          if (matched.isEmpty) continue;

          if (!firstGroup) {
            result.add(const MenuItem.separator());
          }
          firstGroup = false;

          if (entry.key != null) {
            result.add(MenuItem.header(label: entry.key!));
          }

          for (final item in matched) {
            final label = item is Map
                ? (item['label'] as String? ??
                      item['name'] as String? ??
                      item.toString())
                : item.toString();
            final itemValue = item is Map
                ? ((item['value'] as T?) ?? (item['name'] as T?) ?? item as T)
                : item as T;
            result.add(
              MenuItem(
                label: label,
                icon: item is Map ? item['icon'] as String? : null,
                enabled: item is Map
                    ? !(item['disabled'] as bool? ?? false)
                    : true,
                selected: itemValue == currentVal,
                onTap: () => onChanged?.call(itemValue),
                hoverIcon: item is Map ? item['hoverIcon'] as String? : null,
                onHoverTap: item is Map
                    ? item['onHoverTap'] as VoidCallback?
                    : null,
              ),
            );
          }
        }
        return result;
      }

      return [
        for (final option in options)
          if (matchesSearch(option.label, option.displayLabel, null))
            MenuItem(
              label: option.label,
              icon: option.icon,
              enabled: option.enabled && enabled,
              selected: option.value == value,
              onTap: () {
                onChanged?.call(option.value);
              },
              hoverIcon: option.hoverIcon,
              onHoverTap: option.onHoverTap,
            ),
      ];
    }

    // 面板顶部搜索条：输入实时过滤（匹配模型名与提供商名），Esc 关闭面板
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
                  dismissMenu();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: SizedBox(
                width: 200,
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
          ),
          AppDivider(size: AppDividerSize.small),
        ],
      );
    }

    // options/data 的内容签名：只有内容真正变化时才触发原地刷新。
    // 调用方每次 build 都会传新数组（如 AgentSelector 的列表推导），
    // 直接依赖 [data, options] 会导致任意 rebuild（如其他信号触发）都
    // 把已打开的全局菜单内容替换成自己的（点击智能体却弹出模型列表）。
    final refreshKey = useMemoized<String>(() {
      final content = data != null
          ? data!
              .map((item) {
                if (item is! Map) return '${item.runtimeType}:$item';
                return [
                  item['label'],
                  item['name'],
                  item['displayLabel'],
                  item['value'],
                  item['icon'],
                  item['group'],
                  item['hoverIcon'],
                  item['disabled'],
                ].join('|');
              })
              .join('\n')
          : options
              .map(
                (o) => [
                  o.value,
                  o.label,
                  o.displayLabel,
                  o.icon,
                  o.hoverIcon,
                  o.enabled,
                ].join('|'),
              )
              .join('\n');
      // 搜索时每次输入变化都要原地刷新列表（过滤结果）
      return searchable ? '$content\nquery:$query' : content;
    }, [data, options, searchQuery.value]);

    // 当 data/options 内容变化时，如果下拉面板已打开，原地刷新内容
    useEffect(() {
      if (!ContextMenu.isOpen || lastPosition.value == null) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!ContextMenu.isOpen) return;
        ContextMenu.show(
          context,
          position: lastPosition.value!,
          minWidth: menuMinWidth,
          maxWidth: menuMaxWidth,
          link: layerLink,
          alignRight: lastAlignRight.value,
          items: buildMenuItems(),
          onDismiss: () => isOpen.value = false,
          header: searchable ? buildSearchHeader() : null,
          emptyPlaceholder: searchable ? '无匹配项' : '无内容',
          initialFocusedIndex: searchable ? 0 : -1,
          autoFocus: !searchable,
        );
      });
      return null;
    }, [refreshKey]);

    void onTap() {
      // 菜单已打开且属于本按钮 → 再次点击收起（不刷新、不重建）。
      // 背景 Listener 已排除锚定按钮区域，不会抢先关闭菜单
      if (ContextMenu.isOpen && ContextMenu.activeLink == layerLink) {
        dismissMenu();
        return;
      }

      onBeforeOpen?.call();

      // Get the button's global position to anchor the menu.
      final renderBox =
          buttonKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;

      final position = renderBox.localToGlobal(Offset.zero);
      lastPosition.value = position;

      // 判断按钮是否靠近屏幕右侧，靠近时菜单靠右对齐，避免右侧出界
      final viewport = View.of(context);
      final screenWidth =
          viewport.physicalSize.width / viewport.devicePixelRatio;
      final buttonRight = position.dx + renderBox.size.width;
      final alignRight = buttonRight > screenWidth / 2;
      lastAlignRight.value = alignRight;

      // 打开时重置搜索：每次打开从空搜索开始
      if (searchable) {
        searchController.clear();
        searchQuery.value = '';
      }

      ContextMenu.show(
        context,
        position: position,
        minWidth: menuMinWidth,
        maxWidth: menuMaxWidth,
        link: layerLink,
        alignRight: alignRight,
        items: buildMenuItems(),
        onDismiss: () => isOpen.value = false,
        // 锚定按钮矩形：菜单背景在点击此区域时不会抢先关闭菜单，
        // 由 onTap 决定收起或切换
        anchorRect: position & renderBox.size,
        header: searchable ? buildSearchHeader() : null,
        emptyPlaceholder: searchable ? '无匹配项' : '无内容',
        initialFocusedIndex: searchable ? 0 : -1,
        // 搜索框接管焦点：不让列表 autofocus 抢占
        autoFocus: !searchable,
      );
      isOpen.value = true;

      if (searchable) {
        // 菜单挂载后把光标聚焦到搜索框（post-frame，
        // 避免与列表 autofocus / 菜单动画竞争）
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!isOpen.value || !ContextMenu.isOpen) return;
          searchFocusNode.requestFocus();
        });
      }
    }

    // 按钮内容：前置图标（可选）+ 文本 + chevron；fullWidth 时左对齐拉满，
    // 否则居中紧凑。文本超长时以省略号截断（受 maxWidth 约束）。
    final textColor = selectedLabel != null
        ? custom.colors.textPrimary
        : custom.colors.textSecondary;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (buttonIcon != null) ...[
          AppIcon(
            buttonIcon!,
            size: custom.typography.captionSize,
            color: textColor,
          ),
          SizedBox(width: custom.spacing.xs),
        ],
        Flexible(
          child: AppText(
            selectedLabel ?? placeholder ?? '',
            variant: AppTextVariant.caption,
            color: textColor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: custom.spacing.xs),
        AppIcon(
          isOpen.value ? 'chevronUp' : 'chevronDown',
          size: custom.typography.captionSize,
          color: custom.colors.textSecondary,
        ),
      ],
    );

    return CompositedTransformTarget(
      link: layerLink,
      child: MouseRegion(
        onEnter: (_) => isHovered.value = true,
        onExit: (_) => isHovered.value = false,
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            key: buttonKey,
            width: fullWidth ? double.infinity : null,
            height: custom.controls.smallHeight,
            constraints: maxWidth != null
                ? BoxConstraints(maxWidth: maxWidth!)
                : null,
            padding: EdgeInsets.symmetric(horizontal: custom.spacing.sm),
            decoration: BoxDecoration(
              color: isHovered.value ? custom.colors.hover : Colors.transparent,
              borderRadius: custom.radii.xs,
            ),
            // 非 fullWidth 时按钮宽度跟随内容（widthFactor 让 Align 收缩到子内容），
            // 超出 maxWidth 由外层 ConstrainedBox 截断；Center 会填满有限 maxWidth 导致宽度固定。
            child: fullWidth
                ? content
                : Align(alignment: Alignment.center, widthFactor: 1.0, child: content),
          ),
        ),
      ),
    );
  }
}
