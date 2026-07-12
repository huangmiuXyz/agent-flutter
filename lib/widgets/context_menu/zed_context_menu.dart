import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:agent/theme/custom_theme.dart';

// ─────────────────────────────────────────────────────────────
// ZedContextMenu — a right-click context menu in Zed IDE style
// ─────────────────────────────────────────────────────────────

/// Describes a single item in the context menu.
class ZedContextMenuEntry {
  final String label;
  final IconData? icon;
  final String? shortcut;
  final bool enabled;
  final bool selected; // checkmark / toggle state
  final List<ZedContextMenuEntry>? submenu;
  final VoidCallback? onTap;

  const ZedContextMenuEntry({
    required this.label,
    this.icon,
    this.shortcut,
    this.enabled = true,
    this.selected = false,
    this.submenu,
    this.onTap,
  });
}

/// Shows a Zed-style context menu at the given position.
///
/// ```dart
/// ZedContextMenu.show(
///   context,
///   position: position,
///   entries: [ ... ],
/// );
/// ```
class ZedContextMenu {
  static OverlayEntry? _current;

  /// Dismiss any visible Zed context menu.
  static void dismiss() {
    _current?.remove();
    _current = null;
  }

  /// Show a context menu at [position] (global coordinates).
  static void show(
    BuildContext context, {
    required Offset position,
    required List<ZedContextMenuEntry> entries,
    double? minWidth,
    double? maxHeight,
    VoidCallback? onDismiss,
  }) {
    dismiss();

    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => _ZedContextMenuWrapper(
        position: position,
        minWidth: minWidth,
        maxHeight: maxHeight,
        entries: entries,
        onDismiss: () {
          dismiss();
          onDismiss?.call();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

// ─────────────────────────────────────────────────────────────
// Internal wrapper — barrier + positioning
// ─────────────────────────────────────────────────────────────

class _ZedContextMenuWrapper extends StatefulWidget {
  final Offset position;
  final double? minWidth;
  final double? maxHeight;
  final List<ZedContextMenuEntry> entries;
  final VoidCallback onDismiss;

  const _ZedContextMenuWrapper({
    required this.position,
    required this.entries,
    required this.onDismiss,
    this.minWidth,
    this.maxHeight,
  });

  @override
  State<_ZedContextMenuWrapper> createState() => _ZedContextMenuWrapperState();
}

class _ZedContextMenuWrapperState extends State<_ZedContextMenuWrapper> {
  final GlobalKey _menuKey = GlobalKey();
  Offset _position = Offset.zero;
  bool _ready = false;

  static const double _margin = 12.0;

  @override
  void initState() {
    super.initState();
    // 先离屏渲染测量尺寸，然后定位到正确位置（消除闪现）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureAndPosition();
    });
  }

  void _measureAndPosition() {
    final renderBox = _menuKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final size = renderBox.size;
    final viewport = View.of(context);
    final screenSize = viewport.physicalSize / viewport.devicePixelRatio;
    final mouseX = widget.position.dx;
    final mouseY = widget.position.dy;

    // ── 水平方向 ──
    // 默认：菜单左边缘 = 鼠标 X
    var dx = mouseX;
    // 如果菜单超出右边界 → 翻转：菜单右边缘 = 鼠标 X（菜单在鼠标左侧弹出）
    if (mouseX + size.width > screenSize.width - _margin) {
      dx = mouseX - size.width;
    }
    // 溢出保护：贴左
    if (dx < _margin) {
      dx = _margin;
    }

    // ── 垂直方向 ──
    // 默认：菜单顶边缘 = 鼠标 Y
    var dy = mouseY;
    // 如果菜单超出下边界 → 翻转：菜单底边缘 = 鼠标 Y（菜单在鼠标上方弹出）
    if (mouseY + size.height > screenSize.height - _margin) {
      dy = mouseY - size.height;
    }
    // 溢出保护：贴上
    if (dy < _margin) {
      dy = _margin;
    }

    setState(() {
      _position = Offset(dx, dy);
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final panel = _ZedContextMenuPanel(
      key: _menuKey,
      entries: widget.entries,
      minWidth: widget.minWidth,
      maxHeight: widget.maxHeight,
      onDismiss: widget.onDismiss,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDismiss,
      onScaleStart: (_) => widget.onDismiss(),
      child: Stack(
        children: [
          const Positioned.fill(child: SizedBox.expand()),
          // _ready 前：离屏渲染用于测量（不可见，不可交互）
          // _ready 后：定位到计算后的正确位置
          Positioned(
            left: _ready ? _position.dx : 0,
            top: _ready ? _position.dy : -10000,
            child: Material(
              type: MaterialType.transparency,
              child: IgnorePointer(ignoring: !_ready, child: panel),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// The reusable panel widget
// ─────────────────────────────────────────────────────────────

class _ZedContextMenuPanel extends StatelessWidget {
  final List<ZedContextMenuEntry> entries;
  final double? minWidth;
  final double? maxHeight;
  final VoidCallback onDismiss;

  const _ZedContextMenuPanel({
    super.key,
    required this.entries,
    required this.onDismiss,
    this.minWidth,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return IntrinsicWidth(
      stepWidth: minWidth ?? 200,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minWidth ?? 200,
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
              children: _buildItems(context, custom),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildItems(BuildContext context, CustomTheme custom) {
    final children = <Widget>[];
    for (final entry in entries) {
      if (entry.label == '---') {
        children.add(_buildSeparator(custom));
      } else if (entry.submenu != null && entry.submenu!.isNotEmpty) {
        children.add(
          _SubmenuItem(entry: entry, custom: custom, onDismiss: onDismiss),
        );
      } else {
        children.add(
          _MenuItem(entry: entry, custom: custom, onDismiss: onDismiss),
        );
      }
    }
    return children;
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

// ─────────────────────────────────────────────────────────────
// Menu item — compact layout using CustomTheme tokens
//
//   Container padding: spacingXs
//   Hover background uses radiusXs
//   Content padding: spacingSm horizontal, spacingXs vertical
//   Shortcut spacing: spacingSm
// ─────────────────────────────────────────────────────────────

class _MenuItem extends StatefulWidget {
  final ZedContextMenuEntry entry;
  final CustomTheme custom;
  final VoidCallback onDismiss;

  const _MenuItem({
    required this.entry,
    required this.custom,
    required this.onDismiss,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final hoverBg = widget.custom.colors.menuHover;
    final textColor = entry.enabled
        ? widget.custom.colors.textPrimary
        : widget.custom.colors.textDisabled;
    final mutedColor = widget.custom.colors.textSecondary;
    final iconColor = entry.enabled ? textColor : mutedColor;

    final labelStyle = TextStyle(
      fontSize: widget.custom.fontSizeCaption,
      color: textColor,
      fontFamily: widget.custom.fontFamily,
      fontWeight: FontWeight.w400,
    );
    final shortcutStyle = TextStyle(
      fontSize: widget.custom.fontSizeCaption,
      color: mutedColor,
      fontFamily: widget.custom.fontFamily,
    );

    // ── Build children imperatively to avoid Dart collection-if parser issues ──
    final rowChildren = <Widget>[];

    // Icon or checkmark slot
    if (entry.selected) {
      rowChildren.add(
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Icon(LucideIcons.check, size: 12, color: iconColor),
        ),
      );
    } else if (entry.icon != null) {
      rowChildren.add(
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Icon(entry.icon, size: 12, color: iconColor),
        ),
      );
    }

    // Label (pushes shortcut to the right)
    rowChildren.add(
      Expanded(
        child: Text(
          entry.label,
          style: labelStyle,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    // Shortcut spacing
    if (entry.shortcut != null) {
      rowChildren.add(SizedBox(width: widget.custom.spacingSm));
      rowChildren.add(Text(entry.shortcut!, style: shortcutStyle));
    }

    // ── Hover container ──
    final inner = Container(
      decoration: BoxDecoration(
        color: (_hovered && entry.enabled) ? hoverBg : Colors.transparent,
        borderRadius: widget.custom.radiusXs,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: widget.custom.spacingSm,
        vertical: widget.custom.spacingXs,
      ),
      child: Row(children: rowChildren),
    );

    return Semantics(
      button: true,
      enabled: entry.enabled,
      label: entry.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: entry.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: entry.enabled
              ? () {
                  widget.onDismiss();
                  entry.onTap?.call();
                }
              : null,
          child: inner,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Submenu item — with chevron
// ─────────────────────────────────────────────────────────────

class _SubmenuItem extends StatefulWidget {
  final ZedContextMenuEntry entry;
  final CustomTheme custom;
  final VoidCallback onDismiss;

  const _SubmenuItem({
    required this.entry,
    required this.custom,
    required this.onDismiss,
  });

  @override
  State<_SubmenuItem> createState() => _SubmenuItemState();
}

class _SubmenuItemState extends State<_SubmenuItem> {
  bool _hovered = false;
  OverlayEntry? _submenuEntry;

  @override
  void dispose() {
    _submenuEntry?.remove();
    super.dispose();
  }

  void _showSubmenu(BuildContext context) {
    _submenuEntry?.remove();
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final overlay = Overlay.of(context, rootOverlay: true);

    _submenuEntry = OverlayEntry(
      builder: (_) => _ZedContextMenuWrapper(
        position: Offset(
          position.dx + renderBox.size.width - 4,
          position.dy - 4,
        ),
        entries: widget.entry.submenu!,
        minWidth: widget.custom.controlHeightMd * 6,
        onDismiss: () {
          _submenuEntry?.remove();
          _submenuEntry = null;
          widget.onDismiss();
        },
      ),
    );
    overlay.insert(_submenuEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final hoverBg = widget.custom.colors.menuHover;
    final textColor = widget.custom.colors.textPrimary;
    final mutedColor = widget.custom.colors.textSecondary;

    final labelStyle = TextStyle(
      fontSize: widget.custom.fontSizeCaption,
      color: textColor,
      fontFamily: widget.custom.fontFamily,
      fontWeight: FontWeight.w400,
    );

    final rowChildren = <Widget>[];

    if (entry.icon != null) {
      rowChildren.add(
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Icon(entry.icon, size: 12, color: textColor),
        ),
      );
    }

    rowChildren.add(
      Expanded(
        child: Text(
          entry.label,
          style: labelStyle,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    rowChildren.add(SizedBox(width: widget.custom.spacingSm));
    rowChildren.add(
      Icon(LucideIcons.chevronRight, size: 10, color: mutedColor),
    );

    final inner = Container(
      decoration: BoxDecoration(
        color: _hovered ? hoverBg : Colors.transparent,
        borderRadius: widget.custom.radiusXs,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: widget.custom.spacingSm,
        vertical: widget.custom.spacingXs,
      ),
      child: Row(children: rowChildren),
    );

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        _showSubmenu(context);
      },
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: inner,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Convenience wrapper — right-click host
// ─────────────────────────────────────────────────────────────

/// Wraps a child widget and opens a [ZedContextMenu] on right-click.
///
/// ```dart
/// ZedContextMenuHost(
///   entries: (ctx) => [
///     const ZedContextMenuEntry(label: 'Copy', shortcut: '⌘C'),
///   ],
///   child: MyWidget(),
/// )
/// ```
class ZedContextMenuHost extends StatefulWidget {
  final Widget child;
  final List<ZedContextMenuEntry> Function(BuildContext) entries;

  const ZedContextMenuHost({
    super.key,
    required this.child,
    required this.entries,
  });

  @override
  State<ZedContextMenuHost> createState() => _ZedContextMenuHostState();
}

class _ZedContextMenuHostState extends State<ZedContextMenuHost> {
  void _onSecondaryTapDown(TapDownDetails details) {
    final entries = widget.entries(context);
    if (entries.isEmpty) return;
    ZedContextMenu.show(
      context,
      position: details.globalPosition,
      entries: entries,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: _onSecondaryTapDown,
      onLongPressStart: (details) {
        final entries = widget.entries(context);
        if (entries.isEmpty) return;
        ZedContextMenu.show(
          context,
          position: details.globalPosition,
          entries: entries,
        );
      },
      child: widget.child,
    );
  }
}
