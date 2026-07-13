import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/card/app_card.dart';
import 'package:agent/widgets/divider/app_divider.dart';

// -------------------- 数据模型 --------------------
class MenuItem {
  final String label;
  final IconData? icon;
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
Offset _adjustMenuPosition({
  required Offset mouse,
  required Size menuSize,
  required Size screenSize,
  double margin = 12,
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
  final VoidCallback onDismiss;
  final void Function(bool)? onHoverChanged;

  const _MenuOverlay({
    required this.position,
    required this.items,
    required this.onDismiss,
    this.minWidth,
    this.maxHeight,
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
        // translucent：自身注册 hit 触发 dismiss，但不吸收事件，
        // 下层 entry（MenuArea 等）仍能收到右键事件
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => onDismiss(),
            child: const SizedBox.expand(),
          ),
        ),
        // 菜单面板（在上层，拦截自身区域的事件）
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
  final VoidCallback onDismiss;

  const _MenuPanel({
    super.key,
    required this.items,
    required this.onDismiss,
    this.minWidth,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    // Track a single close callback for the currently open submenu.
    // When a new item opens its submenu, it closes any previously open one.
    final closeCurrentSubmenu = useRef<VoidCallback?>(null);

    void closeOtherSubmenu() {
      closeCurrentSubmenu.value?.call();
    }

    void registerCloseSubmenu(VoidCallback closeFn) {
      closeCurrentSubmenu.value = closeFn;
    }

    return AppCard(
      minWidth: minWidth ?? custom.controls.mediumHeight * 4,
      maxHeight: maxHeight,
      backgroundColor: custom.colors.menuBackground,
      border: Border.all(color: custom.colors.menuBorder, width: 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items.map((item) {
          if (item.isSeparator) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: custom.spacing.xs),
              child: AppDivider(
                thickness: 1,
                extent: custom.spacing.xs * 2 + 1,
                indent: 0,
                endIndent: 0,
                color: custom.colors.menuHover,
              ),
            );
          }
          return _MenuItemWidget(
            item: item,
            custom: custom,
            onDismiss: onDismiss,
            closeOtherSubmenu: closeOtherSubmenu,
            registerCloseSubmenu: registerCloseSubmenu,
          );
        }).toList(),
      ),
    );
  }
}

// -------------------- 菜单项（支持子菜单） --------------------
class _MenuItemWidget extends HookWidget {
  final MenuItem item;
  final CustomTheme custom;
  final VoidCallback onDismiss;
  final VoidCallback closeOtherSubmenu;
  final void Function(VoidCallback) registerCloseSubmenu;

  const _MenuItemWidget({
    required this.item,
    required this.custom,
    required this.onDismiss,
    required this.closeOtherSubmenu,
    required this.registerCloseSubmenu,
  });

  @override
  Widget build(BuildContext context) {
    final hovered = useState(false);
    final submenuOverlay = useRef<OverlayEntry?>(null);
    final isSubmenu = item.submenu != null && item.submenu!.isNotEmpty;
    final openTimer = useRef<Timer?>(null);
    final closeTimer = useRef<Timer?>(null);

    useEffect(
      () => () {
        openTimer.value?.cancel();
        closeTimer.value?.cancel();
        submenuOverlay.value?.remove();
      },
      [],
    );

    void cancelTimers() {
      openTimer.value?.cancel();
      openTimer.value = null;
      closeTimer.value?.cancel();
      closeTimer.value = null;
    }

    void closeSubmenu() {
      if (submenuOverlay.value != null) {
        submenuOverlay.value?.remove();
        submenuOverlay.value = null;
        // Clear the ref in panel so stale callback won't linger.
        registerCloseSubmenu(() {});
      }
    }

    void showSubmenu(BuildContext context) {
      if (!isSubmenu || !item.enabled) return;
      cancelTimers();
      // Close any previously open submenu first.
      closeOtherSubmenu();
      submenuOverlay.value?.remove();
      final renderBox = context.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      final overlay = Overlay.of(context, rootOverlay: true);

      submenuOverlay.value = OverlayEntry(
        builder: (_) => _MenuOverlay(
          position: Offset(
            position.dx + renderBox.size.width - 4,
            position.dy - 4,
          ),
          items: item.submenu!,
          minWidth: custom.controlHeightMd * 6,
          onHoverChanged: (isHovered) {
            if (isHovered) cancelTimers();
          },
          onDismiss: () {
            cancelTimers();
            submenuOverlay.value?.remove();
            submenuOverlay.value = null;
            onDismiss();
          },
        ),
      );
      overlay.insert(submenuOverlay.value!);

      // Register callback to close this submenu when another item opens its own.
      registerCloseSubmenu(() {
        cancelTimers();
        closeSubmenu();
      });
    }

    void scheduleOpen(BuildContext context) {
      if (!isSubmenu || !item.enabled) return;
      cancelTimers();
      // Delay before opening so that quickly brushing past adjacent items
      // doesn't cause flicker — only open after the user lingers.
      openTimer.value = Timer(const Duration(milliseconds: 300), () {
        if (hovered.value) {
          showSubmenu(context);
        }
      });
    }

    final hoverBg = custom.colors.menuHover;
    final textColor = item.enabled
        ? custom.colors.textPrimary
        : custom.colors.textDisabled;
    final mutedColor = item.enabled
        ? custom.colors.textSecondary
        : custom.colors.textDisabled;

    final children = <Widget>[
      if (item.selected)
        Icon(LucideIcons.check, size: 12, color: textColor)
      else if (item.icon != null)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Icon(item.icon!, size: 12, color: textColor),
        ),
      Expanded(
        child: Text(
          item.label,
          style: TextStyle(
            fontSize: custom.fontSizeCaption,
            color: textColor,
            fontFamily: custom.fontFamily,
            fontWeight: FontWeight.w400,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (item.shortcut != null) ...[
        SizedBox(width: custom.spacingSm),
        Text(
          item.shortcut!,
          style: TextStyle(
            fontSize: custom.fontSizeCaption,
            color: mutedColor,
            fontFamily: custom.fontFamily,
          ),
        ),
      ],
      if (isSubmenu) ...[
        SizedBox(width: custom.spacingSm),
        Icon(LucideIcons.chevronRight, size: 10, color: mutedColor),
      ],
    ];

    return Semantics(
      button: true,
      enabled: item.enabled,
      label: item.label,
      child: MouseRegion(
        onEnter: (_) {
          if (!item.enabled) return;
          hovered.value = true;
          cancelTimers();
          // Don't open submenu immediately — wait a short while to avoid
          // flicker when scanning across adjacent items with submenus.
          scheduleOpen(context);
        },
        onExit: (_) {
          hovered.value = false;
          cancelTimers();
          if (isSubmenu && submenuOverlay.value != null) {
            // Short delay before closing so mouse can slide into the submenu.
            closeTimer.value = Timer(const Duration(milliseconds: 200), () {
              if (!hovered.value && submenuOverlay.value != null) {
                closeSubmenu();
              }
            });
          }
        },
        cursor: item.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: item.enabled
              ? () {
                  onDismiss();
                  item.onTap?.call();
                }
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: hovered.value && item.enabled
                  ? hoverBg
                  : Colors.transparent,
              borderRadius: custom.radiusXs,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: custom.spacingSm,
              vertical: custom.spacingXs,
            ),
            child: Row(children: children),
          ),
        ),
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
    // Use Listener for secondary click to bypass the gesture arena entirely.
    // GestureDetector with deferToChild (default) can lose the right-click
    // event when TerminalView's internal recognizers claim it first.
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
