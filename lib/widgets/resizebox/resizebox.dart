import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';

/// Direction of the resize handle relative to the resizable [ResizeBox.child].
enum ResizeDirection {
  right,
  left,
  bottom,
  top;

  bool get isHorizontal =>
      this == ResizeDirection.left || this == ResizeDirection.right;
  bool get isVertical => !isHorizontal;
}

/// A resizable split-panel with two slots and VS Code-style auto-collapse.
///
/// [child] is the resizable panel. [other] fills the remaining space.
class ResizeBox extends HookWidget {
  const ResizeBox({
    super.key,
    required this.child,
    required this.other,
    this.direction = ResizeDirection.right,
    this.minSize = 180,
    this.maxSize = 600,
    this.initialSize = 256,
    this.collapseThreshold = 80,
    this.onCollapseChanged,
  });

  final Widget child;
  final Widget other;
  final ResizeDirection direction;
  final double minSize;
  final double maxSize;
  final double initialSize;
  final double collapseThreshold;
  final ValueChanged<bool>? onCollapseChanged;

  @override
  Widget build(BuildContext context) {
    final isHorizontal = direction.isHorizontal;
    final targetSize = useState(initialSize.clamp(minSize, maxSize));
    final isCollapsed = useState(false);
    final isDragging = useState(false);
    final dragRawTarget = useRef(0.0);
    final dragRenderBox = useRef<RenderBox?>(null);

    RenderBox? resolveRenderBox() {
      // onDragUpdate only fires after onDragStart sets dragRenderBox,
      // so the cached value is always present during a drag gesture.
      // The fallback is a defensive safety net.
      return dragRenderBox.value ?? context.findRenderObject() as RenderBox?;
    }

    double localCoord(RenderBox renderBox, Offset localPos) {
      return switch (direction) {
        ResizeDirection.right => localPos.dx,
        ResizeDirection.left => renderBox.size.width - localPos.dx,
        ResizeDirection.bottom => localPos.dy,
        ResizeDirection.top => renderBox.size.height - localPos.dy,
      };
    }

    void onDragStart(DragStartDetails d) {
      isDragging.value = true;
      final renderBox = context.findRenderObject() as RenderBox;
      dragRenderBox.value = renderBox;
      dragRawTarget.value = localCoord(
        renderBox,
        renderBox.globalToLocal(d.globalPosition),
      );
    }

    void onDragEnd(DragEndDetails d) {
      isDragging.value = false;
      dragRenderBox.value = null;
      if (isCollapsed.value) {
        targetSize.value = 0;
      } else if (targetSize.value < minSize) {
        targetSize.value = minSize;
      }
    }

    void onDragUpdate(DragUpdateDetails d) {
      final renderBox = resolveRenderBox();
      if (renderBox == null) return;
      final rawTarget = localCoord(
        renderBox,
        renderBox.globalToLocal(d.globalPosition),
      );
      dragRawTarget.value = rawTarget;

      if (isCollapsed.value) {
        if (rawTarget >= minSize) {
          isCollapsed.value = false;
          targetSize.value = rawTarget.clamp(minSize, maxSize);
          onCollapseChanged?.call(false);
        } else {
          targetSize.value = 0;
        }
      } else {
        if (rawTarget < minSize) {
          if ((minSize - rawTarget) >= collapseThreshold) {
            isCollapsed.value = true;
            targetSize.value = 0;
            onCollapseChanged?.call(true);
          } else {
            targetSize.value = minSize;
          }
        } else if (rawTarget > maxSize) {
          targetSize.value = maxSize;
        } else {
          targetSize.value = rawTarget;
        }
      }
    }

    void onExpandTap() {
      if (isCollapsed.value) {
        isCollapsed.value = false;
        targetSize.value = initialSize.clamp(minSize, maxSize);
        onCollapseChanged?.call(false);
      }
    }

    // ---- build sized child ----
    Widget sizedChild() {
      final raw = isDragging.value
          ? dragRawTarget.value.clamp(minSize, maxSize)
          : targetSize.value;
      final size = isCollapsed.value ? targetSize.value : raw;
      final effective = size < 0.5 ? 0.0 : size;
      return ClipRect(
        child: isHorizontal
            ? SizedBox(width: effective, child: child)
            : SizedBox(height: effective, child: child),
      );
    }

    // ---- layout ----
    return Stack(
      children: [
        if (isHorizontal)
          Row(
            children: [
              if (direction == ResizeDirection.right) sizedChild(),
              if (direction == ResizeDirection.left) Expanded(child: other),
              if (direction == ResizeDirection.left) sizedChild(),
              if (direction == ResizeDirection.right) Expanded(child: other),
            ],
          )
        else
          Column(
            children: [
              if (direction == ResizeDirection.bottom) sizedChild(),
              if (direction == ResizeDirection.top) Expanded(child: other),
              if (direction == ResizeDirection.top) sizedChild(),
              if (direction == ResizeDirection.bottom) Expanded(child: other),
            ],
          ),

        // Resize handle
        _ResizeHandle(
          direction: direction,
          minSize: minSize,
          maxSize: maxSize,
          collapseThreshold: collapseThreshold,
          isCollapsed: isCollapsed,
          targetSize: targetSize,
          dragRawTarget: dragRawTarget,
          isDragging: isDragging,
          onDragStart: onDragStart,
          onDragUpdate: onDragUpdate,
          onDragEnd: onDragEnd,
          onExpandTap: onExpandTap,
        ),

        // Cursor overlay during drag
        if (isDragging.value)
          Positioned.fill(
            child: MouseRegion(
              cursor: isHorizontal
                  ? SystemMouseCursors.resizeLeftRight
                  : SystemMouseCursors.resizeUpDown,
              child: IgnorePointer(ignoring: true, child: SizedBox.expand()),
            ),
          ),
      ],
    );
  }
}

/// The resize handle / edge strip rendered by [ResizeBox].
///
/// Owns its hover visuals and timer-based edge reveal when collapsed.
class _ResizeHandle extends HookWidget {
  final ResizeDirection direction;
  final double minSize;
  final double maxSize;
  final double collapseThreshold;
  final ValueNotifier<bool> isCollapsed;
  final ValueNotifier<double> targetSize;
  final dynamic dragRawTarget; // ValueRef<double> from useRef
  final ValueNotifier<bool> isDragging;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final VoidCallback onExpandTap;

  const _ResizeHandle({
    required this.direction,
    required this.minSize,
    required this.maxSize,
    required this.collapseThreshold,
    required this.isCollapsed,
    required this.targetSize,
    required this.dragRawTarget,
    required this.isDragging,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onExpandTap,
  });

  static const Duration _collapsedHoverDelay = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final isHorizontal = direction.isHorizontal;
    final handleOffset = _ResizeHandleStatic.handleHitSize / 2;

    final isHoveringHandle = useState(false);
    final isHoveringEdge = useState(false);
    final hoverTimer = useRef<Timer?>(null);

    final collapsed = isCollapsed.value;
    final showVisual = collapsed
        ? (isHoveringEdge.value || isDragging.value)
        : (isHoveringHandle.value || isDragging.value);
    final handleColor = collapsed
        ? custom.colors.accentHover
        : custom.colors.accent;

    final rawForPos = (collapsed || !isDragging.value)
        ? targetSize.value
        : dragRawTarget.value;
    final handlePos = rawForPos.clamp(minSize, maxSize);

    double? left, right, top, bottom;

    if (collapsed) {
      switch (direction) {
        case ResizeDirection.right:
          left = 0;
          top = 0;
          bottom = 0;
        case ResizeDirection.left:
          right = 0;
          top = 0;
          bottom = 0;
        case ResizeDirection.bottom:
          top = 0;
          left = 0;
          right = 0;
        case ResizeDirection.top:
          bottom = 0;
          left = 0;
          right = 0;
      }
    } else {
      switch (direction) {
        case ResizeDirection.right:
          left = handlePos - handleOffset;
          top = 0;
          bottom = 0;
        case ResizeDirection.left:
          right = handlePos - handleOffset;
          top = 0;
          bottom = 0;
        case ResizeDirection.bottom:
          top = handlePos - handleOffset;
          left = 0;
          right = 0;
        case ResizeDirection.top:
          bottom = handlePos - handleOffset;
          left = 0;
          right = 0;
      }
    }

    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      width: isHorizontal ? _ResizeHandleStatic.handleHitSize : null,
      height: isHorizontal ? null : _ResizeHandleStatic.handleHitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: collapsed ? onExpandTap : null,
        onHorizontalDragStart: isHorizontal ? onDragStart : null,
        onHorizontalDragUpdate: isHorizontal ? onDragUpdate : null,
        onHorizontalDragEnd: isHorizontal ? onDragEnd : null,
        onVerticalDragStart: isHorizontal ? null : onDragStart,
        onVerticalDragUpdate: isHorizontal ? null : onDragUpdate,
        onVerticalDragEnd: isHorizontal ? null : onDragEnd,
        child: MouseRegion(
          cursor: isHorizontal
              ? SystemMouseCursors.resizeLeftRight
              : SystemMouseCursors.resizeUpDown,
          onEnter: (_) {
            hoverTimer.value?.cancel();
            hoverTimer.value = Timer(_collapsedHoverDelay, () {
              if (collapsed) {
                isHoveringEdge.value = true;
              } else {
                isHoveringHandle.value = true;
              }
            });
          },
          onExit: (_) {
            hoverTimer.value?.cancel();
            hoverTimer.value = null;
            if (collapsed) {
              isHoveringEdge.value = false;
            } else {
              isHoveringHandle.value = false;
            }
          },
          child: collapsed
              ? Align(
                  alignment: switch (direction) {
                    ResizeDirection.right => Alignment.centerLeft,
                    ResizeDirection.left => Alignment.centerRight,
                    ResizeDirection.bottom => Alignment.topCenter,
                    ResizeDirection.top => Alignment.bottomCenter,
                  },
                  child: _bar(isHorizontal, custom, showVisual, handleColor),
                )
              : Center(
                  child: _bar(isHorizontal, custom, showVisual, handleColor),
                ),
        ),
      ),
    );
  }

  Widget _bar(
    bool isHorizontal,
    CustomTheme custom,
    bool showVisual,
    Color handleColor,
  ) {
    return Container(
      width: isHorizontal ? custom.spacing.xs : double.infinity,
      height: isHorizontal ? double.infinity : custom.spacing.xs,
      color: showVisual ? handleColor : Colors.transparent,
    );
  }
}

/// Static constants shared by [_ResizeHandle].
class _ResizeHandleStatic {
  static const double handleHitSize = 10;
}
