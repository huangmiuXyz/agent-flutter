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

  /// Creates a regular menu item.
  const MenuItem({
    required this.label,
    this.icon,
    this.shortcut,
    this.enabled = true,
    this.selected = false,
    this.submenu,
    this.onTap,
  }) : isSeparator = false;

  /// Creates a menu separator (dividing line).
  const MenuItem.separator()
    : label = '---',
      icon = null,
      shortcut = null,
      enabled = false,
      selected = false,
      submenu = null,
      onTap = null,
      isSeparator = true;
}

// -------------------- 全局菜单管理 --------------------
class ContextMenu {
  static OverlayEntry? _overlayEntry;

  static void dismiss() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  static void show(
    BuildContext context, {
    required Offset position,
    required List<MenuItem> items,
    double? minWidth,
    double? maxHeight,
    bool autoFocus = true,
    VoidCallback? onDismiss,
  }) {
    dismiss();
    final overlay = Overlay.of(context, rootOverlay: true);
    _overlayEntry = OverlayEntry(
      builder: (_) => _MenuOverlay(
        position: position,
        items: items,
        minWidth: minWidth,
        maxHeight: maxHeight,
        autoFocus: autoFocus,
        onDismiss: () {
          dismiss();
          onDismiss?.call();
        },
      ),
    );
    overlay.insert(_overlayEntry!);
  }
}

// -------------------- 工具：位置修正 --------------------
/// Minimum edge margin for context menu positioning.
const double _menuEdgeMargin = 12;

Offset _adjustMenuPosition({
  required Offset mouse,
  required Size menuSize,
  required Size screenSize,
  double margin = _menuEdgeMargin,
}) {
  double dx = mouse.dx;
  double dy = mouse.dy;
  if (mouse.dx + menuSize.width > screenSize.width - margin) {
    dx = mouse.dx - menuSize.width;
  }
  if (dx < margin) dx = margin;
  if (mouse.dy + menuSize.height > screenSize.height - margin) {
    dy = mouse.dy - menuSize.height;
  }
  if (dy < margin) dy = margin;
  return Offset(dx, dy);
}

// -------------------- 菜单覆盖层 --------------------
class _MenuOverlay extends HookWidget {
  final Offset position;
  final List<MenuItem> items;
  final double? minWidth;
  final double? maxHeight;
  final bool autoFocus;
  final VoidCallback onDismiss;
  final void Function(bool)? onHoverChanged;

  const _MenuOverlay({
    required this.position,
    required this.items,
    required this.onDismiss,
    this.minWidth,
    this.maxHeight,
    this.autoFocus = true,
    this.onHoverChanged,
  });

  @override
  Widget build(BuildContext context) {
    final menuKey = useState(GlobalKey());
    final offset = useState(Offset.zero);
    final ready = useState(false);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
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
        );
        ready.value = true;
      });
      return null;
    }, []);

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
        Positioned(
          left: offset.value.dx,
          top: offset.value.dy,
          child: Opacity(
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
          ),
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

    // Compact fixed item height for context menus, so total panel height can
    // be snapped to whole items (avoiding half-cut items at the bottom).
    final double menuItemHeight = custom.controls.smallHeight;

    Widget buildMenuItem(MenuItem item) {
      final hasSubmenu = item.submenu != null && item.submenu!.isNotEmpty;

      return AppListItem(
        icon: item.icon,
        label: item.label,
        trailing: hasSubmenu ? null : item.shortcut,
        disabled: !item.enabled,
        active: item.selected,
        intrinsicHeight: false,
        itemHeight: menuItemHeight,
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
                          // Submenu ≈ 6× medium control height wide
                          minWidth: custom.controls.mediumHeight * 6,
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
    const double heightTolerance = 4.0;
    final double unitHeight = menuItemHeight + custom.spacing.xs; // item + gap
    final double cardPadding = custom.spacing.xs * 2;             // top + bottom
    final double maxMenuHeight = cardPadding
        + maxVisibleItems * unitHeight
        - custom.spacing.xs  // last item has no trailing gap
        + heightTolerance;

    return AppCard(
      // Menu ≈ 4× medium control height wide
      minWidth: minWidth ?? custom.controls.mediumHeight * 4,
      maxHeight: maxMenuHeight,
      backgroundColor: custom.colors.menuBackground,
      border: Border.all(color: custom.colors.menuBorder, width: 1),
      child: AppList(
        size: AppListSize.small,
        keyboardNavigable: true,
        autoFocus: autoFocus,
        children: [
          for (final item in items)
            if (item.isSeparator) buildSeparator() else buildMenuItem(item),
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
