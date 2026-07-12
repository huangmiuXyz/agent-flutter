import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
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

class _ZedContextMenuWrapper extends HookWidget {
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
  Widget build(BuildContext context) {
    const double margin = 12.0;
    final menuKey = useMemoized(() => GlobalKey());
    final pos = useState(Offset.zero);
    final ready = useState(false);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final renderBox =
            menuKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize) return;

        final size = renderBox.size;
        final viewport = View.of(context);
        final screenSize = viewport.physicalSize / viewport.devicePixelRatio;
        final mouseX = position.dx;
        final mouseY = position.dy;

        var dx = mouseX;
        if (mouseX + size.width > screenSize.width - margin) {
          dx = mouseX - size.width;
        }
        if (dx < margin) {
          dx = margin;
        }

        var dy = mouseY;
        if (mouseY + size.height > screenSize.height - margin) {
          dy = mouseY - size.height;
        }
        if (dy < margin) {
          dy = margin;
        }

        pos.value = Offset(dx, dy);
        ready.value = true;
      });
      return null;
    }, []);

    final panel = _ZedContextMenuPanel(
      key: menuKey,
      entries: entries,
      minWidth: minWidth,
      maxHeight: maxHeight,
      onDismiss: onDismiss,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      onScaleStart: (_) => onDismiss(),
      child: Stack(
        children: [
          const Positioned.fill(child: SizedBox.expand()),
          // ready 前：离屏渲染用于测量（不可见，不可交互）
          // ready 后：定位到计算后的正确位置
          Positioned(
            left: ready.value ? pos.value.dx : 0,
            top: ready.value ? pos.value.dy : -10000,
            child: Material(
              type: MaterialType.transparency,
              child: IgnorePointer(ignoring: !ready.value, child: panel),
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

class _MenuItem extends HookWidget {
  final ZedContextMenuEntry entry;
  final CustomTheme custom;
  final VoidCallback onDismiss;

  const _MenuItem({
    required this.entry,
    required this.custom,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final hovered = useState(false);
    final hoverBg = custom.colors.menuHover;
    final textColor = entry.enabled
        ? custom.colors.textPrimary
        : custom.colors.textDisabled;
    final mutedColor = custom.colors.textSecondary;
    final iconColor = entry.enabled ? textColor : mutedColor;

    final labelStyle = TextStyle(
      fontSize: custom.fontSizeCaption,
      color: textColor,
      fontFamily: custom.fontFamily,
      fontWeight: FontWeight.w400,
    );
    final shortcutStyle = TextStyle(
      fontSize: custom.fontSizeCaption,
      color: mutedColor,
      fontFamily: custom.fontFamily,
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
      rowChildren.add(SizedBox(width: custom.spacingSm));
      rowChildren.add(Text(entry.shortcut!, style: shortcutStyle));
    }

    // ── Hover container ──
    final inner = Container(
      decoration: BoxDecoration(
        color: (hovered.value && entry.enabled) ? hoverBg : Colors.transparent,
        borderRadius: custom.radiusXs,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: custom.spacingSm,
        vertical: custom.spacingXs,
      ),
      child: Row(children: rowChildren),
    );

    return Semantics(
      button: true,
      enabled: entry.enabled,
      label: entry.label,
      child: MouseRegion(
        onEnter: (_) => hovered.value = true,
        onExit: (_) => hovered.value = false,
        cursor: entry.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: entry.enabled
              ? () {
                  onDismiss();
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

class _SubmenuItem extends HookWidget {
  final ZedContextMenuEntry entry;
  final CustomTheme custom;
  final VoidCallback onDismiss;

  const _SubmenuItem({
    required this.entry,
    required this.custom,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final hovered = useState(false);
    final submenuEntry = useRef<OverlayEntry?>(null);

    useEffect(() {
      return () => submenuEntry.value?.remove();
    }, []);

    void showSubmenu(BuildContext context) {
      submenuEntry.value?.remove();
      final renderBox = context.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      final overlay = Overlay.of(context, rootOverlay: true);

      submenuEntry.value = OverlayEntry(
        builder: (_) => _ZedContextMenuWrapper(
          position: Offset(
            position.dx + renderBox.size.width - 4,
            position.dy - 4,
          ),
          entries: entry.submenu!,
          minWidth: custom.controlHeightMd * 6,
          onDismiss: () {
            submenuEntry.value?.remove();
            submenuEntry.value = null;
            onDismiss();
          },
        ),
      );
      overlay.insert(submenuEntry.value!);
    }

    final hoverBg = custom.colors.menuHover;
    final textColor = entry.enabled
        ? custom.colors.textPrimary
        : custom.colors.textDisabled;
    final mutedColor = entry.enabled
        ? custom.colors.textSecondary
        : custom.colors.textDisabled;

    final labelStyle = TextStyle(
      fontSize: custom.fontSizeCaption,
      color: textColor,
      fontFamily: custom.fontFamily,
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

    rowChildren.add(SizedBox(width: custom.spacingSm));
    rowChildren.add(
      Icon(LucideIcons.chevronRight, size: 10, color: mutedColor),
    );

    final inner = Container(
      decoration: BoxDecoration(
        color: hovered.value && entry.enabled ? hoverBg : Colors.transparent,
        borderRadius: custom.radiusXs,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: custom.spacingSm,
        vertical: custom.spacingXs,
      ),
      child: Row(children: rowChildren),
    );

    return MouseRegion(
      onEnter: (_) {
        if (!entry.enabled) return;
        hovered.value = true;
        showSubmenu(context);
      },
      onExit: (_) => hovered.value = false,
      cursor: entry.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
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
class ZedContextMenuHost extends StatelessWidget {
  final Widget child;
  final List<ZedContextMenuEntry> Function(BuildContext) entries;

  const ZedContextMenuHost({
    super.key,
    required this.child,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) {
        final items = entries(context);
        if (items.isEmpty) return;
        ZedContextMenu.show(
          context,
          position: details.globalPosition,
          entries: items,
        );
      },
      onLongPressStart: (details) {
        final items = entries(context);
        if (items.isEmpty) return;
        ZedContextMenu.show(
          context,
          position: details.globalPosition,
          entries: items,
        );
      },
      child: child,
    );
  }
}
