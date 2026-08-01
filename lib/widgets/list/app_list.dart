import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter/services.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/text/app_text.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/divider/app_divider.dart';

// Re-export so callers can pass AppTextVariant without importing app_text.dart.
export 'package:agent/widgets/text/app_text.dart' show AppTextVariant;

/// Controls the visual density of [AppList], [AppListGroup], and [AppListItem].
///
/// * [AppListSize.normal] — standard sidebar/list density (default).
/// * [AppListSize.small] — compact density matching context menus.
enum AppListSize { normal, small }

/// Inherited widget that propagates [AppListSize] down the widget tree.
class _AppListInheritedSize extends InheritedWidget {
  final AppListSize size;

  const _AppListInheritedSize({required this.size, required super.child});

  static AppListSize? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_AppListInheritedSize>()
        ?.size;
  }

  @override
  bool updateShouldNotify(_AppListInheritedSize oldWidget) =>
      oldWidget.size != size;
}

// ---------------------------------------------------------------------------
// AppList keyboard navigation shared state
// ---------------------------------------------------------------------------

/// Flat entry describing a keyboard-navigable item inside [AppList].
class _NavEntry {
  /// Index of this child in [AppList.children].
  final int childIndex;

  /// Index within a group if the child is inside an [AppListGroup], else null.
  final int? groupChildIndex;

  /// The tap callback.
  final VoidCallback? onTap;

  const _NavEntry(this.childIndex, this.groupChildIndex, this.onTap);
}

/// Builds a flat list of navigable entries from [AppList] children.
///
/// Recurse into [AppListGroup] to pick up its children.
List<_NavEntry> _collectNavEntries(List<Widget> children) {
  final result = <_NavEntry>[];
  for (int i = 0; i < children.length; i++) {
    final child = children[i];
    if (child is AppListItem && child.onTap != null && !child.disabled) {
      result.add(_NavEntry(i, null, child.onTap));
    } else if (child is AppListGroup) {
      for (int j = 0; j < child.children.length; j++) {
        final gc = child.children[j];
        if (gc is AppListItem && gc.onTap != null && !gc.disabled) {
          result.add(_NavEntry(i, j, gc.onTap));
        }
      }
    }
  }
  return result;
}

/// Shared keyboard navigation logic for arrow-up/down, enter, and escape.
///
/// Returns `true` if the key was consumed. Returns `false` to let the event
/// propagate (escape resets the focus index but lets the parent handle it).
bool _handleNavKey({
  required LogicalKeyboardKey key,
  required int focusedIdx,
  required void Function(int) setFocusedIdx,
  required List<_NavEntry> navEntries,
  required VoidCallback scrollFocusedIntoView,
}) {
  if (navEntries.isEmpty) return false;

  if (key == LogicalKeyboardKey.arrowDown) {
    setFocusedIdx(focusedIdx < 0 ? 0 : (focusedIdx + 1) % navEntries.length);
    scrollFocusedIntoView();
    return true;
  }

  if (key == LogicalKeyboardKey.arrowUp) {
    setFocusedIdx(
      focusedIdx < 0
          ? navEntries.length - 1
          : (focusedIdx - 1 + navEntries.length) % navEntries.length,
    );
    scrollFocusedIntoView();
    return true;
  }

  if ((key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select) &&
      focusedIdx >= 0 &&
      focusedIdx < navEntries.length) {
    navEntries[focusedIdx].onTap?.call();
    return true;
  }

  if (key == LogicalKeyboardKey.escape) {
    setFocusedIdx(-1);
    return false;
  }

  return false;
}

// ---------------------------------------------------------------------------
// AppList
// ---------------------------------------------------------------------------

/// Raw data model for a single item inside [AppList.data].
///
/// The component automatically creates [AppListItem]s (and optionally
/// wraps grouped items in [AppListGroup]) from these lightweight descriptors.
class AppList extends HookWidget {
  final double? width;
  final EdgeInsetsGeometry? containerPadding;
  final double? itemGap;
  final BorderRadiusGeometry? containerRadius;
  final Color? containerColor;

  /// Static children (rendered in a [Column]).
  ///
  /// Use [data] instead for a data-driven approach.
  final List<Widget>? children;

  /// Number of items when using [itemBuilder] (virtual scrolling mode).
  final int? itemCount;

  /// Builder called for each visible item in virtual scrolling mode.
  ///
  /// Signature: `(BuildContext context, int index, bool isFocused)`.
  final Widget Function(BuildContext context, int index, bool isFocused)?
  itemBuilder;

  /// Data-driven mode — raw items from JSON.
  ///
  /// Each item is displayed as:
  /// - `item['label'] ?? item['name'] ?? item.toString()` if it's a Map
  /// - `item.toString()` otherwise
  ///
  /// When [data] is provided, [children] and [itemBuilder] are ignored.
  final List<dynamic>? data;

  /// Called when a data-driven item is tapped. Receives the raw item.
  final ValueChanged<dynamic>? onItemTap;

  /// Visual density. Defaults to [AppListSize.normal].
  final AppListSize size;

  /// Whether to enable keyboard navigation (↑↓ to move, Enter to confirm).
  final bool keyboardNavigable;

  /// When [keyboardNavigable] is true, whether to request focus automatically
  /// when the widget is inserted into the tree (e.g. for context menus).
  final bool autoFocus;

  /// 键盘导航的初始选中索引（如命令面板打开即选中第一项）。
  /// 默认 -1 表示初始不选中任何项。
  final int initialFocusedIndex;

  /// Placeholder text shown when the list has no items.
  /// Defaults to `'无内容'`. Set to `null` to show nothing.
  final String? emptyPlaceholder;

  /// 键盘导航聚焦高亮的圆角（默认 [CustomTheme.radii.sm]）。
  final BorderRadiusGeometry? focusRadius;

  const AppList({
    super.key,
    this.width,
    this.containerPadding,
    this.itemGap,
    this.containerRadius,
    this.containerColor,
    this.children,
    this.itemCount,
    this.itemBuilder,
    this.data,
    this.onItemTap,
    this.size = AppListSize.normal,
    this.keyboardNavigable = false,
    this.autoFocus = false,
    this.initialFocusedIndex = -1,
    this.emptyPlaceholder = '无内容',
    this.focusRadius,
  }) : assert(
         (children != null ? 1 : 0) +
                 (itemBuilder != null ? 1 : 0) +
                 (data != null ? 1 : 0) ==
             1,
         'Provide one of [children], [itemBuilder]+[itemCount], or [data].',
       ),
       assert(
         itemBuilder == null || itemCount != null,
         '[itemCount] is required when [itemBuilder] is provided.',
       );

  /// Convert [data] into a widget list with [AppListItem]s and [AppListGroup]s.
  List<Widget> _buildDataChildren() {
    if (data == null) return const [];

    // Collect items by group (null key = ungrouped)
    final Map<String?, List<dynamic>> grouped = {};
    for (final item in data!) {
      final group = item is Map ? item['group'] as String? : null;
      grouped.putIfAbsent(group, () => []).add(item);
    }

    final children = <Widget>[];

    for (final entry in grouped.entries) {
      final groupLabel = entry.key;
      final items = entry.value;

      if (groupLabel != null) {
        children.add(AppListGroup(
          title: groupLabel,
          children: items.map((item) => _buildItemWidget(item)).toList(),
        ));
      } else {
        for (final item in items) {
          children.add(_buildItemWidget(item));
        }
      }
    }

    return children;
  }

  /// Build a single [AppListItem] from a raw data item.
  Widget _buildItemWidget(dynamic item) {
    final label = item is Map
        ? (item['label'] as String? ?? item['name'] as String? ?? item.toString())
        : item.toString();
    final icon = item is Map ? item['icon'] as String? : null;
    final disabled = item is Map ? (item['disabled'] as bool? ?? false) : false;
    final selected = item is Map ? (item['selected'] as bool? ?? false) : false;

    return AppListItem(
      icon: icon,
      label: label,
      disabled: disabled,
      active: selected,
      onTap: onItemTap != null ? () => onItemTap!(item) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Resolve effective children: data → children → empty
    final effectiveChildren = data != null ? _buildDataChildren() : children ?? [];

    final useBuilder = itemBuilder != null;

    // ── Keyboard navigation state ────────────────────────────────────
    final itemCount_ = useBuilder ? itemCount! : effectiveChildren.length;
    final navEntries = useMemoized(() {
      if (useBuilder) {
        return List.generate(itemCount!, (i) => _NavEntry(i, null, null));
      }
      return _collectNavEntries(effectiveChildren);
    }, useBuilder ? [itemCount] : [effectiveChildren]);
    final navEntriesRef = useRef(navEntries);
    navEntriesRef.value = navEntries;

    final scrollController = useMemoized(() => ScrollController());

    final focusNode = useFocusNode();
    // 初始选中索引（如命令面板打开即选中第一项）
    final focusedIdx = useState<int>(initialFocusedIndex);
    final focusKeyRef = useRef<GlobalKey?>(null);
    final focusKeysRef = useRef(<int, GlobalKey>{});

    final custom = CustomTheme.of(context);

    final effectivePadding =
        containerPadding ??
        (size == AppListSize.small
            ? EdgeInsets.zero
            : EdgeInsets.all(custom.spacing.sm));
    final effectiveGap = itemGap ?? custom.spacing.xs;

    void scrollFocusedIntoView() {
      if (useBuilder) {
        final idx = focusedIdx.value;
        if (idx < 0) return;
        final offset = idx * (custom.controls.mediumHeight + effectiveGap);
        scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
        );
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = focusKeyRef.value?.currentContext;
        if (ctx == null) return;
        final renderBox = ctx.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize) return;

        final scrollableState = Scrollable.of(ctx);
        final scrollRenderBox =
            scrollableState.context.findRenderObject() as RenderBox?;
        if (scrollRenderBox == null) return;
        final itemOffset = renderBox.localToGlobal(
          Offset.zero,
          ancestor: scrollRenderBox,
        );
        final viewportHeight = scrollableState.position.viewportDimension;
        if (itemOffset.dy >= 0 &&
            itemOffset.dy + renderBox.size.height <= viewportHeight) {
          return;
        }

        Scrollable.ensureVisible(ctx, alignment: 1.0);
      });
    }

    // ── Passive keyboard listener ──────────────────────────────────────
    // 列表内容变化（如搜索过滤）后，选中索引可能越界 → 钳制到有效范围
    useEffect(() {
      final len = navEntries.length;
      if (len == 0) {
        if (focusedIdx.value != -1) focusedIdx.value = -1;
      } else if (focusedIdx.value >= len) {
        focusedIdx.value = len - 1;
      }
      return null;
    }, [navEntries.length]);

    useEffect(() {
      if (!keyboardNavigable || autoFocus) return null;

      bool handler(KeyEvent event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
        return _handleNavKey(
          key: event.logicalKey,
          focusedIdx: focusedIdx.value,
          setFocusedIdx: (v) => focusedIdx.value = v,
          navEntries: navEntriesRef.value,
          scrollFocusedIntoView: scrollFocusedIntoView,
        );
      }

      HardwareKeyboard.instance.addHandler(handler);
      return () => HardwareKeyboard.instance.removeHandler(handler);
    }, [keyboardNavigable, autoFocus, itemCount_]);

    useEffect(() {
      if (autoFocus && keyboardNavigable && navEntries.isNotEmpty) {
        focusNode.requestFocus();
      }
      return null;
    }, [autoFocus, keyboardNavigable, navEntries.length]);

    // ── Build content ──────────────────────────────────────────────────
    Widget buildChild(int childIndex, Widget child, {bool isFocused = false}) {
      if (!useBuilder) {
        final ff = focusedIdx.value;
        isFocused =
            ff >= 0 &&
            ff < navEntries.length &&
            navEntries[ff].childIndex == childIndex;
      }

      // 分组：把聚焦高亮下放到组内对应子项（避免整个组块被罩上背景）
      if (child is AppListGroup && !useBuilder) {
        final ff = focusedIdx.value;
        int? focusedInGroup;
        if (ff >= 0 && ff < navEntries.length) {
          final e = navEntries[ff];
          if (e.childIndex == childIndex && e.groupChildIndex != null) {
            focusedInGroup = e.groupChildIndex;
          }
        }
        return AppListGroup(
          icon: child.icon,
          title: child.title,
          header: child.header,
          padding: child.padding,
          itemGap: child.itemGap,
          size: child.size,
          showDivider: child.showDivider,
          focusedChildIndex: focusedInGroup,
          focusRadius: focusRadius,
          children: child.children,
        );
      }

      final key = focusKeysRef.value.putIfAbsent(childIndex, () => GlobalKey());
      if (isFocused) focusKeyRef.value = key;

      return Opacity(
        opacity: 1.0,
        child: Container(
          key: key,
          decoration: BoxDecoration(
            color: isFocused ? custom.colors.hover : Colors.transparent,
            borderRadius: focusRadius ?? custom.radii.sm,
          ),
          child: child,
        ),
      );
    }

    // ── Content widget ─────────────────────────────────────────────────
    Widget listBody;

    if (useBuilder) {
      // Virtual scrolling mode
      listBody = ListView.builder(
        controller: scrollController,
        itemCount: itemCount!,
        itemBuilder: (context, i) {
          final child = itemBuilder!(context, i, focusedIdx.value == i);
          return Padding(
            padding: EdgeInsets.only(top: i > 0 ? effectiveGap : 0),
            child: buildChild(i, child, isFocused: focusedIdx.value == i),
          );
        },
      );
    } else if (effectiveChildren.isEmpty && emptyPlaceholder != null) {
      // Empty placeholder
      listBody = Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: custom.spacing.md),
          child: AppText(
            emptyPlaceholder!,
            variant: AppTextVariant.body,
            color: custom.colors.textDisabled,
          ),
        ),
      );
    } else {
      // Static Column mode
      listBody = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < effectiveChildren.length; i++) ...[
            if (i > 0) SizedBox(height: effectiveGap),
            buildChild(i, effectiveChildren[i]),
          ],
        ],
      );
    }

    // ── Focus wrapper ──────────────────────────────────────────────────
    if (keyboardNavigable && autoFocus) {
      listBody = Focus(
        focusNode: focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          final handled = _handleNavKey(
            key: event.logicalKey,
            focusedIdx: focusedIdx.value,
            setFocusedIdx: (v) => focusedIdx.value = v,
            navEntries: navEntries,
            scrollFocusedIntoView: scrollFocusedIntoView,
          );
          return handled ? KeyEventResult.handled : KeyEventResult.ignored;
        },
        child: listBody,
      );
    }

    return _AppListInheritedSize(
      size: size,
      child: Container(
        width: width,
        padding: effectivePadding,
        decoration: BoxDecoration(
          color: containerColor ?? Colors.transparent,
          borderRadius: (containerRadius ?? custom.radii.sm) as BorderRadius,
        ),
        child: listBody,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppListGroup
// ---------------------------------------------------------------------------

/// A group inside [AppList] with an optional title header.
///
/// Typically used when the parent [AppList] is driven by [children].
/// When driving [AppList] via [data], groups are created automatically
/// via [AppListDataItem.group].
class AppListGroup extends StatelessWidget {
  /// Optional icon name for the group header (resolved via [AppIcon]).
  final String? icon;

  /// Title text for the group header.
  final String? title;

  /// Custom header widget. When provided, [icon] and [title] are ignored.
  final Widget? header;

  /// Extra padding around the group children (not including the header).
  final EdgeInsetsGeometry? padding;

  /// Gap between items inside this group.
  final double? itemGap;

  /// The items inside this group (typically [AppListItem]s).
  final List<Widget> children;

  /// Visual density. Inherits from parent [AppList] when not set.
  final AppListSize? size;

  /// Whether to show a separator line above this group.
  final bool showDivider;

  /// 键盘导航时组内被聚焦的子项索引；null 表示无聚焦项（不显示高亮）。
  final int? focusedChildIndex;

  /// 聚焦高亮的圆角（默认 [CustomTheme.radii.sm]）。
  final BorderRadiusGeometry? focusRadius;

  const AppListGroup({
    super.key,
    this.icon,
    this.title,
    this.header,
    this.padding,
    this.itemGap,
    this.size,
    this.showDivider = false,
    this.focusedChildIndex,
    this.focusRadius,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final effectiveSize =
        size ?? _AppListInheritedSize.maybeOf(context) ?? AppListSize.normal;
    final isSmall = effectiveSize == AppListSize.small;
    final effectiveItemGap = itemGap ?? custom.spacing.xs;

    return _AppListInheritedSize(
      size: effectiveSize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Custom header
          ?header,
          // Default header
          if (header == null && title != null)
            _GroupHeader(
              icon: icon,
              title: title!,
              showDivider: showDivider,
              isSmall: isSmall,
              custom: custom,
            ),
          // Group items
          Padding(
            padding: padding ?? EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  if (i > 0) SizedBox(height: effectiveItemGap),
                  // 键盘导航聚焦时仅高亮组内对应单项（不罩住整个组块）
                  if (focusedChildIndex == i)
                    Container(
                      decoration: BoxDecoration(
                        color: custom.colors.hover,
                        borderRadius: focusRadius ?? custom.radii.sm,
                      ),
                      child: children[i],
                    )
                  else
                    children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppListItem
// ---------------------------------------------------------------------------

/// A single row inside [AppList] or [AppListGroup].
class AppListItem extends HookWidget {
  final String? icon;
  final String label;
  final String? trailing;
  final bool active;
  final bool disabled;
  final VoidCallback? onTap;

  final double? itemHeight;
  final EdgeInsetsGeometry? itemPadding;
  final BorderRadiusGeometry? itemRadius;
  final Color? itemColor;

  /// 仅覆盖激活（选中）状态的背景色，优先级高于 [itemColor]。
  final Color? activeColor;
  final Color? labelColor;
  final double? iconSize;
  final double? iconLabelGap;

  /// Optional widget placed after [trailing] text (e.g. submenu chevron).
  final Widget? trailingWidget;

  /// Override the label text variant.
  final AppTextVariant? labelVariant;

  /// When provided, replaces the default [AppText] label with a custom widget.
  /// The widget is placed inside an [Expanded] and inherits the item's foreground color.
  final Widget? labelWidget;

  /// When true, the item height is determined by its content (padding + text)
  /// instead of a fixed [itemHeight] or the default [CustomTheme.controls.mediumHeight].
  final bool? intrinsicHeight;

  /// Called when hover state changes. Provides the item's RenderBox.
  final void Function(bool isHovered, RenderBox renderBox)? onHover;

  /// Optional widgets shown on the trailing side only when the item is hovered.
  /// Useful for action buttons like delete or edit that appear on hover.
  final List<Widget>? hoverActions;

  /// Visual density. Inherits from parent [AppList] or [AppListGroup] when not set.
  final AppListSize? size;

  const AppListItem({
    super.key,
    this.icon,
    required this.label,
    this.trailing,
    this.active = false,
    this.disabled = false,
    this.onTap,
    this.itemHeight,
    this.itemPadding,
    this.itemRadius,
    this.itemColor,
    this.activeColor,
    this.labelColor,
    this.iconSize,
    this.iconLabelGap,
    this.trailingWidget,
    this.labelVariant,
    this.labelWidget,
    this.intrinsicHeight,
    this.onHover,
    this.hoverActions,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isHovered = useState(false);
    final isPressed = useState(false);
    final enabled = !disabled;
    final renderBoxRef = useRef<RenderBox?>(null);

    final custom = CustomTheme.of(context);
    final effectiveSize =
        size ?? _AppListInheritedSize.maybeOf(context) ?? AppListSize.normal;
    final isSmall = effectiveSize == AppListSize.small;

    final padding =
        itemPadding ??
        (isSmall
            ? EdgeInsets.symmetric(
                horizontal: custom.spacing.sm,
                vertical: custom.spacing.xs,
              )
            : EdgeInsets.symmetric(horizontal: custom.spacing.sm));
    final radius =
        (itemRadius ?? (isSmall ? custom.radii.xs : custom.radii.sm))
            as BorderRadius;
    final iconSz =
        iconSize ??
        (isSmall ? custom.typography.captionSize : custom.typography.bodySize);
    final gap = iconLabelGap ?? custom.spacing.sm;

    final bgColor = switch ((active, isPressed.value, isHovered.value)) {
      (true, _, _) => itemColor ?? activeColor ?? custom.colors.selected,
      (_, true, _) when enabled => itemColor ?? custom.colors.selected,
      (_, _, true) when enabled => itemColor ?? custom.colors.hover,
      _ => Colors.transparent,
    };
    final foreground = enabled
        ? (labelColor ?? custom.colors.textPrimary)
        : custom.colors.textDisabled;

    final effectiveIntrinsicHeight = intrinsicHeight ?? isSmall;
    final effectiveLabelVariant =
        labelVariant ??
        (isSmall ? AppTextVariant.caption : AppTextVariant.body);

    final fixedHeight = effectiveIntrinsicHeight
        ? null
        : (itemHeight ?? custom.controls.mediumHeight);

    Widget child = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Material(
        color: bgColor,
        borderRadius: radius,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: radius,
          onHover: (value) {
            isHovered.value = value;
            if (onHover != null) {
              final box = renderBoxRef.value ??=
                  context.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize) {
                onHover!(value, box);
              }
            }
          },
          onHighlightChanged: (value) => isPressed.value = value,
          splashFactory: NoSplash.splashFactory,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                if (icon != null) ...[
                  AppIcon(icon!, size: iconSz, color: foreground),
                  SizedBox(width: gap),
                ],
                Expanded(
                  child:
                      labelWidget ??
                      AppText(
                        label,
                        variant: effectiveLabelVariant,
                        color: foreground,
                      ),
                ),
                // Build trailing content with hover actions floating on top
                () {
                  final trailingChildren = <Widget>[];
                  if (trailing != null) {
                    trailingChildren.add(
                      Padding(
                        padding: EdgeInsets.only(left: custom.spacing.sm),
                        child: AppText(
                          trailing!,
                          variant: AppTextVariant.caption,
                          color: enabled
                              ? custom.colors.textSecondary
                              : custom.colors.textDisabled,
                        ),
                      ),
                    );
                  }
                  if (trailingWidget != null) {
                    trailingChildren.add(
                      Padding(
                        padding: EdgeInsets.only(left: custom.spacing.sm),
                        child: trailingWidget,
                      ),
                    );
                  }

                  // 没有行尾内容且没有悬停操作时直接返回；
                  // 有 hoverActions 时仍需进入下方 Stack 以浮出悬停按钮
                  if (trailingChildren.isEmpty && hoverActions == null) {
                    return const SizedBox.shrink();
                  }

                  // Hide trailing content on hover when hoverActions are present
                  // (use Opacity so layout space is preserved for the floating button)
                  final hideTrailing =
                      trailingChildren.isNotEmpty &&
                      hoverActions != null &&
                      isHovered.value;
                  Widget content = Opacity(
                    opacity: hideTrailing ? 0.0 : 1.0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: trailingChildren,
                    ),
                  );

                  if (hoverActions != null) {
                    final minHoverHeight = isSmall
                        ? custom.controls.smallHeight
                        : custom.controls.mediumHeight;
                    content = ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: minHoverHeight,
                        // 行尾无内容时也预留一个按钮宽度：否则浮出的按钮是
                        // Positioned 溢出子项，绘制可见但 hit-test 不可命中，
                        // 点击会穿透到下层导致菜单误关闭
                        minWidth: minHoverHeight,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          content,
                          if (isHovered.value)
                            Positioned(
                              right: 0,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: hoverActions!
                                    .map(
                                      (action) => Padding(
                                        padding: EdgeInsets.only(
                                          left: custom.spacing.xs,
                                        ),
                                        child: action,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                    );
                  }

                  return content;
                }(),
              ],
            ),
          ),
        ),
      ),
    );

    if (fixedHeight != null) {
      child = SizedBox(height: fixedHeight, child: child);
    }
    return child;
  }
}

// ---------------------------------------------------------------------------
// _GroupHeader
// ---------------------------------------------------------------------------

/// Default group header used by [AppListGroup] when no custom [header] is given.
class _GroupHeader extends StatelessWidget {
  final String? icon;
  final String title;
  final bool showDivider;
  final bool isSmall;
  final CustomTheme custom;

  const _GroupHeader({
    this.icon,
    required this.title,
    required this.showDivider,
    required this.isSmall,
    required this.custom,
  });

  @override
  Widget build(BuildContext context) {
    final padding = isSmall
        ? EdgeInsets.fromLTRB(
            custom.spacing.sm + 2,
            custom.spacing.xs + 2,
            0,
            custom.spacing.xs + 2,
          )
        : EdgeInsets.fromLTRB(0, custom.spacing.xs + 2, 0, custom.spacing.xs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDivider)
          Padding(
            padding: EdgeInsets.only(bottom: custom.spacing.xs),
            child: AppDivider(size: AppDividerSize.small),
          ),
        Padding(
          padding: padding,
          child: Row(
            children: [
              if (icon != null) ...[
                AppIcon(
                  icon!,
                  size: custom.typography.captionSize,
                  color: custom.colors.textSecondary,
                ),
                SizedBox(width: custom.spacing.sm),
              ],
              AppText(
                title,
                variant: AppTextVariant.caption,
                color: custom.colors.textSecondary,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
