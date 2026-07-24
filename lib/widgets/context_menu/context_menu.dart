import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/card/app_card.dart';
import 'package:agent/widgets/list/app_list.dart';
import 'package:agent/widgets/divider/app_divider.dart';
import 'package:agent/widgets/text/app_text.dart';

// -------------------- 数据模型 --------------------
class MenuItem {
  final String label;
  final String? icon;
  final String? shortcut;
  final bool enabled;
  final bool selected;
  final List<MenuItem>? submenu;
  final VoidCallback? onTap;
  final bool isSeparator;
  final bool isHeader;

  /// Creates a regular menu item.
  const MenuItem({
    required this.label,
    this.icon,
    this.shortcut,
    this.enabled = true,
    this.selected = false,
    this.submenu,
    this.onTap,
  }) : isSeparator = false,
       isHeader = false;

  /// Creates a menu separator (dividing line).
  const MenuItem.separator()
    : label = '---',
      icon = null,
      shortcut = null,
      enabled = false,
      selected = false,
      submenu = null,
      onTap = null,
      isSeparator = true,
      isHeader = false;

  /// Creates a group header item (non-selectable, bold label).
  const MenuItem.header({
    required this.label,
    this.icon,
  }) : shortcut = null,
      enabled = false,
      selected = false,
      submenu = null,
      onTap = null,
      isSeparator = false,
      isHeader = true;
}

// -------------------- 全局菜单管理 --------------------
class ContextMenu {
  static OverlayEntry? _overlayEntry;

  // Latest parameters — kept alive so we can update the overlay IN PLACE
  // without dismiss+recreate (which would destroy child widget state).
  static Offset? _lastPosition;
  static List<MenuItem>? _lastItems;
  static double? _lastMinWidth;
  static double? _lastMaxHeight;
  static bool _lastAutoFocus = true;
  static LayerLink? _lastLink;
  static VoidCallback? _lastOnDismiss;

  static void dismiss() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _lastPosition = null;
    _lastItems = null;
    _lastOnDismiss = null;
  }

  static void show(
    BuildContext context, {
    required Offset position,
    required List<MenuItem> items,
    double? minWidth,
    double? maxHeight,
    bool autoFocus = true,
    LayerLink? link,
    VoidCallback? onDismiss,
  }) {
    // Store latest params so the overlay builder picks them up.
    _lastPosition = position;
    _lastItems = items;
    _lastMinWidth = minWidth;
    _lastMaxHeight = maxHeight;
    _lastAutoFocus = autoFocus;
    _lastLink = link;
    _lastOnDismiss = onDismiss;

    if (_overlayEntry != null) {
      // Update existing overlay IN PLACE — no dismiss.
      // The builder reads the static fields above, so when it rebuilds
      // it picks up the new items/position.  Child widget state (keyboard
      // focus, hover, etc.) is preserved because the Element tree stays
      // alive.
      _overlayEntry!.markNeedsBuild();
      return;
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    _overlayEntry = OverlayEntry(
      builder: (_) => _MenuOverlay(
        position: _lastPosition!,
        items: _lastItems!,
        minWidth: _lastMinWidth,
        maxHeight: _lastMaxHeight,
        link: _lastLink,
        autoFocus: _lastAutoFocus,
        onDismiss: () {
          dismiss();
          _lastOnDismiss?.call();
        },
      ),
    );
    overlay.insert(_overlayEntry!);
  }
}

// -------------------- 工具：位置修正 --------------------

Offset _adjustMenuPosition({
  required Offset mouse,
  required Size menuSize,
  required Size screenSize,
  required double margin,
}) {
  double dx = mouse.dx;
  if (mouse.dx + menuSize.width > screenSize.width - margin) {
    dx = screenSize.width - margin - menuSize.width;
  }
  if (dx < margin) dx = margin;

  // 优先向上弹出：菜单放在锚点上方
  double dy = mouse.dy - menuSize.height - margin;
  if (dy < margin) {
    // 上方空间不够 → 放到下方
    dy = mouse.dy + margin;
    if (dy + menuSize.height > screenSize.height - margin) {
      // 下方也不够 → 贴顶
      dy = margin;
    }
  }
  return Offset(dx, dy);
}

// -------------------- 菜单覆盖层 --------------------
class _MenuOverlay extends HookWidget {
  final Offset position;
  final List<MenuItem> items;
  final double? minWidth;
  final double? maxHeight;
  final bool autoFocus;
  final LayerLink? link;
  final VoidCallback onDismiss;
  final void Function(bool)? onHoverChanged;

  const _MenuOverlay({
    required this.position,
    required this.items,
    required this.onDismiss,
    this.minWidth,
    this.maxHeight,
    this.autoFocus = true,
    this.link,
    this.onHoverChanged,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final menuKey = useRef(GlobalKey());
    final offset = useState(Offset.zero);
    final ready = useState(false);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (link != null) {
          // 有 LayerLink 时由 CompositedTransformFollower 自动跟踪位置
          ready.value = true;
          return;
        }
        final renderBox =
            menuKey.value.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize) return;
        final size = renderBox.size;
        final viewport = View.of(context);
        final screenSize = viewport.physicalSize / viewport.devicePixelRatio;
        offset.value = _adjustMenuPosition(
          mouse: position,
          menuSize: size,
          screenSize: screenSize,
          margin: custom.spacing.edgeMargin,
        );
        ready.value = true;
      });
      return null;
    }, []);

    // 当有 LayerLink 时，根据锚点位置决定菜单向上还是向下展开
    final bool showAbove;
    if (link != null) {
      final viewport = View.of(context);
      final screenSize = viewport.physicalSize / viewport.devicePixelRatio;
      showAbove = position.dy >= screenSize.height - position.dy;
    } else {
      showAbove = false;
    }

    final menuContent = Opacity(
      opacity: ready.value ? 1.0 : 0.0,
      child: Material(
        type: MaterialType.transparency,
        child: MouseRegion(
          onEnter: (_) => onHoverChanged?.call(true),
          onExit: (_) => onHoverChanged?.call(false),
          child: _MenuPanel(
            key: menuKey.value,
            items: items,
            minWidth: minWidth,
            maxHeight: maxHeight,
            autoFocus: autoFocus,
            onDismiss: onDismiss,
          ),
        ),
      ),
    );

    return Stack(
      children: [
        // 全屏 dismiss 背景
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => onDismiss(),
            child: const SizedBox.expand(),
          ),
        ),
        if (link != null)
          CompositedTransformFollower(
            link: link!,
            targetAnchor:
                showAbove ? Alignment.topLeft : Alignment.bottomLeft,
            followerAnchor:
                showAbove ? Alignment.bottomLeft : Alignment.topLeft,
            offset: Offset(
              0,
              showAbove ? -custom.spacing.edgeMargin : custom.spacing.edgeMargin,
            ),
            child: menuContent,
          )
        else
          Positioned(
            left: offset.value.dx,
            top: offset.value.dy,
            child: menuContent,
          ),
      ],
    );
  }
}

// -------------------- 菜单面板（容器） --------------------
class _MenuPanel extends HookWidget {
  final List<MenuItem> items;
  final double? minWidth;
  final double? maxHeight;
  final bool autoFocus;
  final VoidCallback onDismiss;

  const _MenuPanel({
    super.key,
    required this.items,
    required this.onDismiss,
    this.minWidth,
    this.maxHeight,
    this.autoFocus = true,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final currentSubmenu = useRef<OverlayEntry?>(null);
    final openTimer = useRef<Timer?>(null);
    final closeTimer = useRef<Timer?>(null);
    final submenuHovered = useRef(false);

    void cancelTimers() {
      openTimer.value?.cancel();
      openTimer.value = null;
      closeTimer.value?.cancel();
      closeTimer.value = null;
    }

    void closeSubmenu() {
      currentSubmenu.value?.remove();
      currentSubmenu.value = null;
    }

    useEffect(
      () => () {
        cancelTimers();
        closeSubmenu();
      },
      [],
    );

    Widget buildSeparator() => AppDivider(size: AppDividerSize.small);

    Widget buildHeader(MenuItem item) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          custom.spacing.sm + 2,
          custom.spacing.sm,
          custom.spacing.sm,
          custom.spacing.xs,
        ),
        child: AppText(
          item.label,
          variant: AppTextVariant.caption,
          color: custom.colors.textSecondary,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    Widget buildMenuItem(MenuItem item) {
      final hasSubmenu = item.submenu != null && item.submenu!.isNotEmpty;

      return AppListItem(
        icon: item.icon,
        label: item.label,
        trailing: hasSubmenu ? null : item.shortcut,
        disabled: !item.enabled,
        active: item.selected,
        intrinsicHeight: false,
        itemHeight: custom.controls.smallHeight,
        trailingWidget: hasSubmenu
            ? AppIcon('chevronRight', size: custom.typography.captionSize)
            : null,
        onHover: hasSubmenu
            ? (isHovered, box) {
                if (isHovered) {
                  submenuHovered.value = false;
                  cancelTimers();
                  openTimer.value = Timer(
                    const Duration(milliseconds: 300),
                    () {
                      closeSubmenu();
                      final pos = box.localToGlobal(Offset.zero);
                      currentSubmenu.value = OverlayEntry(
                        builder: (_) => _MenuOverlay(
                          position: Offset(
                            pos.dx + box.size.width - custom.spacing.xs,
                            pos.dy - custom.spacing.xs,
                          ),
                          items: item.submenu!,
                          minWidth: custom.controls.contextMenuSubmenuWidth,
                          onHoverChanged: (h) {
                            submenuHovered.value = h;
                            if (h) cancelTimers();
                          },
                          onDismiss: () {
                            cancelTimers();
                            closeSubmenu();
                            onDismiss();
                          },
                        ),
                      );
                      Overlay.of(
                        context,
                        rootOverlay: true,
                      ).insert(currentSubmenu.value!);
                    },
                  );
                } else {
                  cancelTimers();
                  if (currentSubmenu.value != null) {
                    closeTimer.value = Timer(
                      const Duration(milliseconds: 200),
                      () {
                        if (!submenuHovered.value &&
                            currentSubmenu.value != null) {
                          closeSubmenu();
                        }
                      },
                    );
                  }
                }
              }
            : null,
        onTap: item.onTap != null
            ? () {
                onDismiss();
                item.onTap?.call();
              }
            : null,
      );
    }

    // Panel always shows at most 10 items; remaining items are scrollable.
    // Add a small tolerance so content exactly fits and SingleChildScrollView
    // doesn't allow spurious scrolling due to font-metric variances.
    const int maxVisibleItems = 10;
    final double unitHeight =
        custom.controls.smallHeight + custom.spacing.xs; // item + gap
    final double cardPadding = custom.spacing.sm; // top + bottom (xs×2)
    final double maxMenuHeight =
        cardPadding +
        maxVisibleItems * unitHeight -
        custom
            .spacing
            .xs // last item has no trailing gap
            +
        custom.spacing.xs; // tolerance for SingleChildScrollView

    return AppCard(
      minWidth: minWidth ?? custom.controls.contextMenuMinWidth,
      maxHeight: maxMenuHeight,
      backgroundColor: custom.colors.menuBackground,
      border: Border.all(color: custom.colors.menuBorder, width: 1),
      child: AppList(
        size: AppListSize.small,
        keyboardNavigable: true,
        autoFocus: autoFocus,
        children: [
          for (final item in items)
            if (item.isSeparator)
              buildSeparator()
            else if (item.isHeader)
              buildHeader(item)
            else
              buildMenuItem(item),
        ],
      ),
    );
  }
}

// -------------------- 便捷区域组件 --------------------
class MenuArea extends StatelessWidget {
  final Widget child;
  final List<MenuItem> Function(BuildContext) builder;

  const MenuArea({super.key, required this.child, required this.builder});

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.kind != PointerDeviceKind.mouse) return;
        if (event.buttons != kSecondaryMouseButton) return;
        final items = builder(context);
        if (items.isEmpty) return;
        ContextMenu.show(context, position: event.position, items: items);
      },
      behavior: HitTestBehavior.translucent,
      child: GestureDetector(
        onLongPressStart: (details) {
          final items = builder(context);
          if (items.isEmpty) return;
          ContextMenu.show(
            context,
            position: details.globalPosition,
            items: items,
          );
        },
        child: child,
      ),
    );
  }
}
