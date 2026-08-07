import 'package:flutter/widgets.dart';

/// 链式滚动物理 — 内层滚动容器到达边界后，由最近的祖先滚动容器接管。
///
/// 用于消息列表内的封顶滚动区（深度思考 / 工具结果 / diff 渲染）：
/// - **拖动接续**：内层滚到底部后继续向下拖动，或滚到顶部后继续向上
///   拖动时，把拖动的偏移增量逐帧转交给外层（消息列表），内层停在
///   边界，实现「内层到底/顶 → 外层接管」的无缝接续；
/// - **动量传递**：内层在边界处松手（fling）时，把惯性速度交给外层
///   （外层用自身 physics 启动惯性滚动），内层停在边界不启动模拟。
///
/// 只拦截边界场景，内层不在边界时完全沿用平台默认行为；
/// 通过 [outerPosition] 动态解析外层 position，找不到祖先滚动容器
/// （独立使用场景）时退化为普通 Clamping 行为。
class ChainedScrollPhysics extends ScrollPhysics {
  /// 最近祖先滚动容器的 position；返回 null 表示无外层（独立滚动）
  final ScrollPosition? Function() outerPosition;

  const ChainedScrollPhysics({
    super.parent,
    required this.outerPosition,
  });

  @override
  ChainedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ChainedScrollPhysics(
      parent: buildParent(ancestor),
      outerPosition: outerPosition,
    );
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // 动量传递：内层在边界处松手（fling），把惯性速度交给外层，
    // 外层用自身 physics 启动惯性滚动；内层停在边界不启动模拟。
    // velocity 符号与像素变化方向一致（> 0 = 向 max 方向）
    if (velocity > 0 && position.pixels >= position.maxScrollExtent) {
      final outer = outerPosition();
      // 普通滚动容器的 position 均为 ScrollPositionWithSingleContext
      if (outer is ScrollPositionWithSingleContext &&
          outer.pixels < outer.maxScrollExtent) {
        outer.goBallistic(velocity);
        return null;
      }
    } else if (velocity < 0 && position.pixels <= position.minScrollExtent) {
      final outer = outerPosition();
      if (outer is ScrollPositionWithSingleContext &&
          outer.pixels > outer.minScrollExtent) {
        outer.goBallistic(velocity);
        return null;
      }
    }
    return super.createBallisticSimulation(position, velocity);
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // 符号约定：offset 为手指位移，position 应用公式为
    // `pixels - applyPhysicsToUserOffset(offset)` ——
    // offset < 0（手指上滑）→ pixels 增加方向；offset > 0 → pixels 减少方向
    // 滚到底部后继续上滑 / 滚到顶部后继续下滑 → 外层接管
    if (offset < 0 && position.pixels >= position.maxScrollExtent) {
      final outer = outerPosition();
      if (outer != null) {
        _chainToOuter(outer, -offset);
        return 0;
      }
    } else if (offset > 0 && position.pixels <= position.minScrollExtent) {
      final outer = outerPosition();
      if (outer != null) {
        _chainToOuter(outer, -offset);
        return 0;
      }
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  /// 把越界增量转交给外层容器（外层按同一公式 `pixels - delta` 移动，
  /// 这里传入的是应用后的位移量，clamp 到外层边界）
  void _chainToOuter(ScrollPosition outer, double delta) {
    if (!outer.hasContentDimensions) return;
    final target = (outer.pixels + delta)
        .clamp(outer.minScrollExtent, outer.maxScrollExtent)
        .toDouble();
    if (target != outer.pixels) {
      outer.jumpTo(target);
    }
  }
}
