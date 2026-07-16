import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';

/// Direction of the resize handle relative to the resizable [ResizeBox.child].
///
/// [ResizeDirection.right]
/// : Handle on the right edge → child is on the left, other on the right.
///
/// [ResizeDirection.left]
/// : Handle on the left edge → child is on the right, other on the left.
///
/// [ResizeDirection.bottom]
/// : Handle on the bottom edge → child is on top, other on bottom.
///
/// [ResizeDirection.top]
/// : Handle on the top edge → child is on bottom, other on top.
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
/// When the user drags past [minSize] for at least [collapseThreshold]
/// pixels, the [child] panel auto-collapses (like VS Code sidebar).
///
/// Supports nesting by placing another [ResizeBox] in [child] or [other].
///
/// ```dart
/// ResizeBox(
///   direction: ResizeDirection.right,
///   child: panel1,
///   other: ResizeBox(
///     direction: ResizeDirection.bottom,
///     child: panel2,
///     other: panel3,
///   ),
/// )
/// ```
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

  /// The resizable panel.
  final Widget child;

  /// The other panel that fills the remaining space.
  final Widget other;

  /// Which edge the resize handle is on.
  final ResizeDirection direction;

  /// Minimum size of the resizable panel (default 180).
  final double minSize;

  /// Maximum size of the resizable panel (default 600).
  final double maxSize;

  /// Initial size (clamped to [minSize]..[maxSize], default 256).
  final double initialSize;

  /// Distance past [minSize] the user must drag before auto-collapse
  /// (default 80 px).
  final double collapseThreshold;

  /// Called when the panel collapses (true) or re-expands (false).
  final ValueChanged<bool>? onCollapseChanged;

  static const double _handleHitSize = 10;
  static const double _handleVisualSize = 4;
  static const Duration _collapsedHoverDelay = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final isHorizontal = direction.isHorizontal;
    final handleOffset = _handleHitSize / 2;

    // --- reactive states ---
    final targetSize = useState(initialSize.clamp(minSize, maxSize));
    final isCollapsed = useState(false);
    final isHoveringHandle = useState(false);
    final isHoveringEdge = useState(false);
    final hoverTimer = useRef<Timer?>(null);

    // --- drag tracking ---
    final isDragging = useState(false);
    final dragRawTarget = useRef(0.0); // mouse-driven raw target
    // Cache the RenderBox across drag frames to avoid per-frame tree traversal.
    final dragRenderBox = useRef<RenderBox?>(null);

    RenderBox resolveRenderBox() {
      return dragRenderBox.value ?? context.findRenderObject() as RenderBox;
    }

    // ---- drag handlers ----

    void onDragStart(DragStartDetails d) {
      isDragging.value = true; // triggers rebuild → shows cursor overlay

      // Cache the RenderBox for the entire drag gesture.
      final renderBox = context.findRenderObject() as RenderBox;
      dragRenderBox.value = renderBox;

      // Initialize dragRawTarget so the first rebuild after dragStart
      // already has a valid position rather than the initial 0.
      final localPos = renderBox.globalToLocal(d.globalPosition);
      switch (direction) {
        case ResizeDirection.right:
          dragRawTarget.value = localPos.dx;
        case ResizeDirection.left:
          dragRawTarget.value = renderBox.size.width - localPos.dx;
        case ResizeDirection.bottom:
          dragRawTarget.value = localPos.dy;
        case ResizeDirection.top:
          dragRawTarget.value = renderBox.size.height - localPos.dy;
      }
    }

    void onDragEnd(DragEndDetails d) {
      isDragging.value = false; // triggers rebuild → removes cursor overlay
      dragRenderBox.value = null; // release cached reference
      if (isCollapsed.value) {
        targetSize.value = 0;
      } else if (targetSize.value < minSize) {
        targetSize.value = minSize;
      }
    }

    void onDragUpdate(DragUpdateDetails d) {
      // Convert mouse screen position to Stack-local coordinates.
      // This gives us the real distance from the Stack's edges,
      // eliminating cumulative errors from reset tracking.
      final renderBox = resolveRenderBox();
      final localPos = renderBox.globalToLocal(d.globalPosition);

      final double rawTarget;
      switch (direction) {
        case ResizeDirection.right:
          rawTarget = localPos.dx;
        case ResizeDirection.left:
          rawTarget = renderBox.size.width - localPos.dx;
        case ResizeDirection.bottom:
          rawTarget = localPos.dy;
        case ResizeDirection.top:
          rawTarget = renderBox.size.height - localPos.dy;
      }
      dragRawTarget.value = rawTarget;

      if (isCollapsed.value) {
        // --- expanding from collapsed ---
        // Stay collapsed until the user drags past minSize, then snap.
        if (rawTarget >= minSize) {
          isCollapsed.value = false;
          targetSize.value = rawTarget.clamp(minSize, maxSize);
          onCollapseChanged?.call(false);
        } else {
          targetSize.value = 0;
        }
      } else {
        // --- normal resize ---
        if (rawTarget < minSize) {
          final excess = minSize - rawTarget;
          if (excess >= collapseThreshold) {
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

    // ---- sub-widget builders ----

    Widget sizedChild() {
      // During drag, read the raw target ref for frame-accurate tracking.
      // Outside drag, use the committed targetSize.
      final raw = isDragging.value
          ? dragRawTarget.value.clamp(minSize, maxSize)
          : targetSize.value;

      // Collapsed state overrides to 0 (isCollapsed is set synchronously in
      // onDragUpdate, so it's current by the time build reads it).
      final size = isCollapsed.value ? targetSize.value : raw;

      final effective = size < 0.5 ? 0.0 : size;
      Widget sized;
      if (isHorizontal) {
        sized = SizedBox(width: effective, child: child);
      } else {
        sized = SizedBox(height: effective, child: child);
      }
      return ClipRect(child: sized);
    }

    Widget resizeEdge() {
      final collapsed = isCollapsed.value;
      final showVisual = collapsed
          ? (isHoveringEdge.value || isDragging.value)
          : (isHoveringHandle.value || isDragging.value);
      final handleColor = collapsed
          ? custom.colors.accent.withValues(alpha: 0.5)
          : custom.colors.accent;

      double? left;
      double? right;
      double? top;
      double? bottom;

      // Handle position driven by raw drag target during drag (syncs to mouse
      // immediately), or by targetSize when not dragging.
      final rawForPos = (collapsed || !isDragging.value)
          ? targetSize.value
          : dragRawTarget.value;
      final handlePos = rawForPos.clamp(minSize, maxSize);

      if (collapsed) {
        // at the very edge of the parent
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
        // center the hit area on the panel edge (which equals the raw mouse
        // position during drag), so the visual bar is right under the cursor
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
        width: isHorizontal ? _handleHitSize : null,
        height: isHorizontal ? null : _handleHitSize,
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
                    child: Container(
                      width: isHorizontal ? _handleVisualSize : double.infinity,
                      height: isHorizontal
                          ? double.infinity
                          : _handleVisualSize,
                      color: showVisual ? handleColor : Colors.transparent,
                    ),
                  )
                : Center(
                    child: Container(
                      width: isHorizontal ? _handleVisualSize : double.infinity,
                      height: isHorizontal
                          ? double.infinity
                          : _handleVisualSize,
                      color: showVisual ? handleColor : Colors.transparent,
                    ),
                  ),
          ),
        ),
      );
    }

    // ---- layout ----

    return Stack(
      children: [
        // main layout: Row or Column with child + other
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

        // resize edge (handle when expanded, edge strip when collapsed)
        resizeEdge(),

        // full-screen cursor overlay during drag
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
