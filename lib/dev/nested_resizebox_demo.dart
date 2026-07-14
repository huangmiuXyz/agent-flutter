import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/widgets/resizebox/resizebox.dart';
import 'package:agent/theme/custom_theme.dart';

/// A demo page showing nested [ResizeBox] configurations.
///
/// Shows three common nesting patterns:
/// 1. Horizontal outer split, vertical inner split (right child)
/// 2. Horizontal outer split, vertical inner split (left child)
/// 3. Two-level deep: horizontal → vertical → horizontal
class NestedResizeBoxDemo extends HookWidget {
  const NestedResizeBoxDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final demoIndex = useState(0);

    final demos = <Widget>[
      _NestedRightDemo(custom: custom),
      _NestedLeftDemo(custom: custom),
      _ThreeLevelDemo(custom: custom),
    ];

    final labels = [
      'Right → Bottom/Top',
      'Left → Bottom/Top',
      'Three-level nesting',
    ];

    return Column(
      children: [
        // tab bar
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: labels.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (context, i) {
              final active = demoIndex.value == i;
              return GestureDetector(
                onTap: () => demoIndex.value = i,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? custom.colors.accent.withValues(alpha: 0.15)
                        : Colors.transparent,
                    border: Border(
                      bottom: BorderSide(
                        color: active
                            ? custom.colors.accent
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: custom.typography.captionSize,
                      color: active
                          ? custom.colors.accent
                          : custom.colors.textSecondary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(child: demos[demoIndex.value]),
      ],
    );
  }
}

/// Horizontal split (right panel), right panel further split vertically
/// into bottom and top.
class _NestedRightDemo extends StatelessWidget {
  const _NestedRightDemo({required this.custom});
  final CustomTheme custom;

  @override
  Widget build(BuildContext context) {
    return ResizeBox(
      direction: ResizeDirection.right,
      minSize: 150,
      initialSize: 200,
      maxSize: 400,
      other: ResizeBox(
        direction: ResizeDirection.bottom,
        minSize: 80,
        initialSize: 150,
        maxSize: 400,
        other: Container(
          color: custom.colors.background,
          child: _PanelLabel(
            label: 'Top-Right Panel\n(inner ResizeBox other)',
            color: custom.colors.accent.withValues(alpha: 0.1),
          ),
        ),
        child: Container(
          color: custom.colors.panel,
          child: _PanelLabel(
            label: 'Bottom-Right Panel\n(inner ResizeBox child)',
            color: custom.colors.accent.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Container(
        color: custom.colors.panel,
        child: _PanelLabel(
          label: 'Left Panel',
          color: custom.colors.accent.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

/// Horizontal split (left panel), left panel further split vertically into
/// bottom and top.
class _NestedLeftDemo extends StatelessWidget {
  const _NestedLeftDemo({required this.custom});
  final CustomTheme custom;

  @override
  Widget build(BuildContext context) {
    return ResizeBox(
      direction: ResizeDirection.left,
      minSize: 150,
      initialSize: 200,
      maxSize: 400,
      other: ResizeBox(
        direction: ResizeDirection.bottom,
        minSize: 80,
        initialSize: 150,
        maxSize: 400,
        other: Container(
          color: custom.colors.background,
          child: _PanelLabel(
            label: 'Top-Left Panel\n(inner ResizeBox other)',
            color: custom.colors.accent.withValues(alpha: 0.1),
          ),
        ),
        child: Container(
          color: custom.colors.panel,
          child: _PanelLabel(
            label: 'Bottom-Left Panel\n(inner ResizeBox child)',
            color: custom.colors.accent.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Container(
        color: custom.colors.panel,
        child: _PanelLabel(
          label: 'Right Panel',
          color: custom.colors.accent.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

/// Three-level nesting: horizontal → bottom → horizontal
class _ThreeLevelDemo extends StatelessWidget {
  const _ThreeLevelDemo({required this.custom});
  final CustomTheme custom;

  @override
  Widget build(BuildContext context) {
    return ResizeBox(
      direction: ResizeDirection.bottom,
      minSize: 80,
      initialSize: 150,
      maxSize: 400,
      other: Container(
        color: custom.colors.panel,
        child: _PanelLabel(
          label: 'Top Panel\n(level 1: other)',
          color: custom.colors.accent.withValues(alpha: 0.3),
        ),
      ),
      child: ResizeBox(
        direction: ResizeDirection.right,
        minSize: 100,
        initialSize: 180,
        maxSize: 400,
        other: Container(
          color: custom.colors.background,
          child: _PanelLabel(
            label: 'Bottom-Right\n(level 3: inner)',
            color: custom.colors.accent.withValues(alpha: 0.1),
          ),
        ),
        child: Container(
          color: custom.colors.panel,
          child: _PanelLabel(
            label: 'Bottom-Left\n(level 3: outer)',
            color: custom.colors.accent.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }
}

class _PanelLabel extends StatelessWidget {
  const _PanelLabel({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Container(
      decoration: BoxDecoration(color: color),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: custom.typography.captionSize,
          color: custom.colors.textSecondary,
        ),
      ),
    );
  }
}
