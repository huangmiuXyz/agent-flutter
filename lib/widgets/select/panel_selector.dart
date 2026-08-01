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

  /// 悬停时行尾浮出的图标（仅鼠标 hover 时显示）。
  final String? hoverIcon;

  /// 点击 [hoverIcon] 按钮时的回调（不触发行本身的选中）。
  final VoidCallback? onHoverTap;

  const PanelSelectorOption({
    required this.value,
    required this.label,
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

  const PanelSelector({
    super.key,
    this.value,
    this.placeholder,
    this.options = const [],
    this.data,
    this.onChanged,
    this.onBeforeOpen,
    this.menuMinWidth = 160,
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

    // Memoize options so they don't recreate on every build.
    final allOptions = useMemoized(() => _allOptions, [data, options]);

    // 找出当前选中值的显示文本
    final selectedLabel = useMemoized(() {
      if (value == null) return null;
      final idx = allOptions.indexWhere((o) => o.value == value);
      return idx >= 0 ? allOptions[idx].label : null;
    }, [value, allOptions]);

    // 上次打开菜单时的位置，用于原地刷新
    final lastPosition = useRef<Offset?>(null);
    final lastAlignRight = useRef<bool>(false);

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
          if (!firstGroup) {
            result.add(const MenuItem.separator());
          }
          firstGroup = false;

          if (entry.key != null) {
            result.add(MenuItem.header(label: entry.key!));
          }

          for (final item in entry.value) {
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

    // 当 data/options 变化时，如果下拉面板已打开，原地刷新内容
    useEffect(() {
      if (!ContextMenu.isOpen || lastPosition.value == null) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!ContextMenu.isOpen) return;
        ContextMenu.show(
          context,
          position: lastPosition.value!,
          minWidth: menuMinWidth,
          link: layerLink,
          alignRight: lastAlignRight.value,
          items: buildMenuItems(),
          onDismiss: () => isOpen.value = false,
        );
      });
      return null;
    }, [data, options]);

    void onTap() {
      // 菜单已打开且属于本按钮 → 再次点击收起（不刷新、不重建）。
      // 背景 Listener 已排除锚定按钮区域，不会抢先关闭菜单
      if (ContextMenu.isOpen && ContextMenu.activeLink == layerLink) {
        isOpen.value = false;
        lastPosition.value = null;
        ContextMenu.dismiss();
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

      ContextMenu.show(
        context,
        position: position,
        minWidth: menuMinWidth,
        link: layerLink,
        alignRight: alignRight,
        items: buildMenuItems(),
        onDismiss: () => isOpen.value = false,
        // 锚定按钮矩形：菜单背景在点击此区域时不会抢先关闭菜单，
        // 由 onTap 决定收起或切换
        anchorRect: position & renderBox.size,
      );
      isOpen.value = true;
    }

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
            height: custom.controls.smallHeight,
            padding: EdgeInsets.symmetric(horizontal: custom.spacing.sm),
            decoration: BoxDecoration(
              color: isHovered.value
                  ? custom.colors.hover
                  : Colors.transparent,
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
                    isOpen.value ? 'chevronUp' : 'chevronDown',
                    size: custom.typography.captionSize,
                    color: custom.colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
