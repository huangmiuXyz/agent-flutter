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

  /// Static children (rendered in a [Column]).
  ///
  /// Use [itemCount] + [itemBuilder] instead for virtual scrolling with large
  /// lists.
  final List<Widget>? children;

  /// Number of items when using [itemBuilder] (virtual scrolling mode).
  final int? itemCount;

  /// Builder called for each visible item in virtual scrolling mode.
  ///
  /// Signature: `(BuildContext context, int index, bool isFocused)`.
  final Widget Function(BuildContext context, int index, bool isFocused)?
  itemBuilder;

  /// Visual density. Defaults to [AppListSize.normal].
  final AppListSize size;

  /// Whether to enable keyboard navigation (↑↓ to move, Enter to confirm).
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
    this.children,
    this.itemCount,
    this.itemBuilder,
    this.size = AppListSize.normal,
    this.keyboardNavigable = false,
    this.autoFocus = false,
  }) : assert(
         (children != null) ^ (itemBuilder != null),
         'Provide either [children] or [itemBuilder]+[itemCount], not both.',
       ),
       assert(
         itemBuilder == null || itemCount != null,
         '[itemCount] is required when [itemBuilder] is provided.',
       );

  @override
  Widget build(BuildContext context) {
    final useBuilder = itemBuilder != null;

    // ── Keyboard navigation state ────────────────────────────────────
    final itemCount_ = useBuilder ? itemCount! : (children?.length ?? 0);
    final navEntries = useMemoized(() {
      if (useBuilder) {
        return List.generate(itemCount!, (i) => _NavEntry(i, null, null));
      }
      return _collectNavEntries(children!);
    }, useBuilder ? [itemCount] : [children]);
    final navEntriesRef = useRef(navEntries);
    navEntriesRef.value = navEntries;

    final scrollController = useMemoized(() => ScrollController());

    final focusNode = useFocusNode();
    final focusedIdx = useState<int>(keyboardNavigable ? 0 : -1);
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

      final key = focusKeysRef.value.putIfAbsent(childIndex, () => GlobalKey());
      if (isFocused) focusKeyRef.value = key;

      return Opacity(
        opacity: 1.0,
        child: Container(
          key: key,
          decoration: BoxDecoration(
            color: isFocused ? custom.colors.hover : Colors.transparent,
            borderRadius: custom.radii.sm,
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
    } else {
      // Static Column mode
      listBody = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children!.length; i++) ...[
            if (i > 0) SizedBox(height: effectiveGap),
            buildChild(i, children![i]),
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

                  if (trailingChildren.isEmpty) return const SizedBox.shrink();

                  // Hide trailing content on hover when hoverActions are present
                  // (use Opacity so layout space is preserved for the floating button)
                  final hideTrailing = hoverActions != null && isHovered.value;
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
                      constraints: BoxConstraints(minHeight: minHoverHeight),
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
