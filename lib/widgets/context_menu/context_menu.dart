import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:agent/theme/custom_theme.dart';

// -------------------- 数据模型 --------------------
class MenuItem {
  final String label;
  final IconData? icon;
  final String? shortcut;
  final bool enabled;
  final bool selected;
  final List<MenuItem>? submenu;
  final VoidCallback? onTap;

  const MenuItem({
    required this.label,
    this.icon,
    this.shortcut,
    this.enabled = true,
    this.selected = false,
    this.submenu,
    this.onTap,
  });
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

  const _MenuOverlay({
    required this.position,
    required this.items,
    required this.onDismiss,
    this.minWidth,
    this.maxHeight,
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
      ],
    );
  }
}

// -------------------- 菜单面板（容器） --------------------
class _MenuPanel extends StatelessWidget {
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
    final effectiveMinWidth = minWidth ?? custom.controlHeightMd * 4;

    return IntrinsicWidth(
      stepWidth: effectiveMinWidth,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight ?? MediaQuery.of(context).size.height * 0.75,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: custom.colors.menuBackground,
            borderRadius: custom.radii.sm,
            border: Border.all(color: custom.colors.menuBorder, width: 1),
            boxShadow: custom.shadows.large,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(custom.spacingXs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: items.map((item) {
                if (item.label == '---') {
                  return _buildSeparator(custom);
                }
                return _MenuItemWidget(
                  item: item,
                  custom: custom,
                  onDismiss: onDismiss,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeparator(CustomTheme custom) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: custom.spacingXs),
      child: Container(
        height: 1,
        margin: EdgeInsets.symmetric(vertical: custom.spacingXs),
        color: custom.colors.menuHover,
      ),
    );
  }
}

// -------------------- 菜单项（支持子菜单） --------------------
class _MenuItemWidget extends HookWidget {
  final MenuItem item;
  final CustomTheme custom;
  final VoidCallback onDismiss;

  const _MenuItemWidget({
    required this.item,
    required this.custom,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final hovered = useState(false);
    final submenuOverlay = useRef<OverlayEntry?>(null);
    final isSubmenu = item.submenu != null && item.submenu!.isNotEmpty;

    useEffect(
      () =>
          () => submenuOverlay.value?.remove(),
      [],
    );

    void showSubmenu(BuildContext context) {
      if (!isSubmenu || !item.enabled) return;
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
          onDismiss: () {
            submenuOverlay.value?.remove();
            submenuOverlay.value = null;
            onDismiss();
          },
        ),
      );
      overlay.insert(submenuOverlay.value!);
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
          showSubmenu(context);
        },
        onExit: (_) => hovered.value = false,
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
