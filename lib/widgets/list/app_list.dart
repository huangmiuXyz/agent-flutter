import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter/services.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';
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

  const _NavEntry({
    required this.childIndex,
    this.groupChildIndex,
    required this.onTap,
  });
}

/// Builds a flat list of navigable entries from [AppList] children.
///
/// Recurse into [AppListGroup] to pick up its children.
List<_NavEntry> _collectNavEntries(List<Widget> children) {
  final result = <_NavEntry>[];
  for (int i = 0; i < children.length; i++) {
    final child = children[i];
    if (child is AppListItem && child.onTap != null && !child.disabled) {
      result.add(_NavEntry(childIndex: i, onTap: child.onTap));
    } else if (child is AppListGroup) {
      for (int j = 0; j < child.children.length; j++) {
        final gc = child.children[j];
        if (gc is AppListItem && gc.onTap != null && !gc.disabled) {
          result.add(_NavEntry(childIndex: i, groupChildIndex: j, onTap: gc.onTap));
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

  if ((key == LogicalKeyboardKey.enter ||
       key == LogicalKeyboardKey.select) &&
      focusedIdx >= 0) {
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

class AppList extends HookWidget {
  final double? width;
  final EdgeInsetsGeometry? containerPadding;
  final double? itemGap;
  final BorderRadiusGeometry? containerRadius;
  final Color? containerColor;
  final List<Widget> children;

  /// Visual density. Defaults to [AppListSize.normal].
  final AppListSize size;

  /// Whether to enable keyboard navigation (↑↓ to move, Enter to confirm).
  ///
  /// When enabled, the widget captures focus and responds to keyboard events.
  final bool keyboardNavigable;

  /// When [keyboardNavigable] is true, whether to request focus automatically
  /// when the widget is inserted into the tree (e.g. for context menus).
  final bool autoFocus;

  const AppList({
    super.key,
    this.width,
    this.containerPadding,
    this.itemGap,
    this.containerRadius,
    this.containerColor,
    this.size = AppListSize.normal,
    this.keyboardNavigable = false,
    this.autoFocus = false,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    final effectivePadding =
        containerPadding ??
        (size == AppListSize.small
            ? EdgeInsets.zero
            : EdgeInsets.all(custom.spacing.sm));
    final effectiveGap = itemGap ?? custom.spacing.xs;

    // Build flat list of navigable items (memoized by children identity).
    final navEntries = useMemoized(() => _collectNavEntries(children), [children]);

    // Keyboard navigation state.
    // Start at 0 when nav is enabled so the first item is focused by default;
    // start at -1 when disabled so nothing appears visually highlighted.
    final focusNode = useFocusNode();
    final focusedIdx = useState<int>(keyboardNavigable ? 0 : -1);

    // GlobalKey for the currently focused child, used to scroll it into view.
    final focusKeyRef = useRef<GlobalKey?>(null);

    // Helper to scroll the focused item into view only if it's not fully visible.
    void scrollFocusedIntoView() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = focusKeyRef.value?.currentContext;
        if (ctx == null) return;
        final renderBox = ctx.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize) return;

        // Check if the item is already fully visible inside the scrollable.
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
          return; // already fully visible
        }

        Scrollable.ensureVisible(ctx, alignment: 1.0);
      });
    }

    // ── Passive keyboard listener (no focus steal) ────────────────────
    // Used when keyboard navigable but NOT auto-focused (e.g. @mention menu).
    useEffect(() {
      if (!keyboardNavigable || autoFocus) return null;

      bool handler(KeyEvent event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
        return _handleNavKey(
          key: event.logicalKey,
          focusedIdx: focusedIdx.value,
          setFocusedIdx: (v) => focusedIdx.value = v,
          navEntries: navEntries,
          scrollFocusedIntoView: scrollFocusedIntoView,
        );
      }

      HardwareKeyboard.instance.addHandler(handler);
      return () => HardwareKeyboard.instance.removeHandler(handler);
    }, [keyboardNavigable, autoFocus, navEntries]);

    // Auto-focus when mounted (only for autoFocus mode).
    useEffect(() {
      if (autoFocus && keyboardNavigable && navEntries.isNotEmpty) {
        focusNode.requestFocus();
      }
      return null;
    }, [autoFocus, keyboardNavigable, navEntries.length]);

    // ── Build the column content ──────────────────────────────────────
    Widget buildChild(int childIndex, Widget child) {
      final ff = focusedIdx.value;
      if (ff < 0 || ff >= navEntries.length) return child;
      final entry = navEntries[ff];
      if (entry.childIndex != childIndex) return child;
      final key = GlobalKey();
      focusKeyRef.value = key;
      return _KeyboardFocusWrapper(
        key: key,
        borderRadius: custom.radii.sm,
        color: custom.colors.hover,
        child: child,
      );
    }

    Widget listBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: effectiveGap),
          buildChild(i, children[i]),
        ],
      ],
    );

    // ── Wrap with Focus widget only when auto-focusing (steals focus) ──
    // When !autoFocus, keyboard is handled by the HardwareKeyboard effect above.
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

  /// Build a single child, wrapping it with a keyboard-focus highlight
  /// if it is the currently focused navigable item.

}

/// Wraps a child with a keyboard-focus background highlight.
///
/// Paints the background behind the child so existing hover/active styles
/// inside the child still work.
class _KeyboardFocusWrapper extends StatelessWidget {
  final BorderRadius borderRadius;
  final Color color;
  final Widget child;

  const _KeyboardFocusWrapper({
    super.key,
    required this.borderRadius,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
      ),
      position: DecorationPosition.background,
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// AppListGroup
// ---------------------------------------------------------------------------

/// A section group for use inside [AppList].
///
/// Renders an optional header (with [icon] and [title] text styled as a
/// section label) followed by a vertical column of [children] (typically
/// [AppListItem]s). Multiple [AppListGroup]s can be placed side-by-side
/// inside an [AppList] to produce a grouped/sectioned sidebar.
///
/// When [size] is not specified, inherits from the nearest ancestor
/// [AppList] or parent [AppListGroup].
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

  const AppListGroup({
    super.key,
    this.icon,
    this.title,
    this.header,
    this.padding,
    this.itemGap,
    this.size,
    this.showDivider = false,
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
  final Color? labelColor;
  final double? iconSize;
  final double? iconLabelGap;

  /// Optional widget placed after [trailing] text (e.g. submenu chevron).
  final Widget? trailingWidget;

  /// Override the label text variant.
  final AppTextVariant? labelVariant;

  /// When true, the item height is determined by its content (padding + text)
  /// instead of a fixed [itemHeight] or the default [CustomTheme.controls.mediumHeight].
  final bool? intrinsicHeight;

  /// Called when hover state changes. Provides the item's RenderBox.
  final void Function(bool isHovered, RenderBox renderBox)? onHover;

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
    this.labelColor,
    this.iconSize,
    this.iconLabelGap,
    this.trailingWidget,
    this.labelVariant,
    this.intrinsicHeight,
    this.onHover,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final effectiveSize =
        size ?? _AppListInheritedSize.maybeOf(context) ?? AppListSize.normal;
    final isSmall = effectiveSize == AppListSize.small;
    final isHovered = useState(false);
    final isPressed = useState(false);
    final enabled = !disabled;
    // Lazily cache the RenderBox so hover callbacks avoid per-event tree traversal.
    final renderBoxRef = useRef<RenderBox?>(null);



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
      (true, _, _) => itemColor ?? custom.colors.selected,
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
                  child: AppText(
                    label,
                    variant: effectiveLabelVariant,
                    color: foreground,
                  ),
                ),
                if (trailing != null)
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
                if (trailingWidget != null)
                  Padding(
                    padding: EdgeInsets.only(left: custom.spacing.sm),
                    child: trailingWidget,
                  ),
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

/// Internal header widget for [AppListGroup].
///
/// When [showDivider] is true, a 1px separator line is rendered at the top
/// of the header's padding area, so the spacing above and below the title
/// remains symmetric.
class _GroupHeader extends StatelessWidget {
  final String? icon;
  final String title;
  final bool showDivider;
  final bool isSmall;
  final CustomTheme custom;

  const _GroupHeader({
    required this.icon,
    required this.title,
    required this.showDivider,
    required this.isSmall,
    required this.custom,
  });

  @override
  Widget build(BuildContext context) {
    final vertical = isSmall ? custom.spacing.xs : custom.spacing.sm;

    final titleRow = Row(
      children: [
        if (icon != null) ...[
          AppIcon(
            icon!,
            size: custom.typography.captionSize,
            color: custom.colors.textSecondary,
          ),
          SizedBox(width: custom.spacing.xs),
        ],
        Expanded(
          child: AppText(
            title,
            variant: AppTextVariant.caption,
            color: custom.colors.textSecondary,
          ),
        ),
      ],
    );

    if (!showDivider) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: custom.spacing.sm,
          vertical: vertical,
        ),
        child: titleRow,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Full-width divider
        AppDivider(thickness: 1),
        // Title with symmetric padding
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: custom.spacing.sm,
            vertical: vertical,
          ),
          child: titleRow,
        ),
      ],
    );
  }
}
