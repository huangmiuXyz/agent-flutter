import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';

/// 面板总宽度（竖条 22 + 间隙 10 + 浮层 240）。
/// _MessageList 定位时：面板 left = 内容右缘 + 8 - (总宽 - 22)，
/// 使竖条保持在内容右缘 +8px，浮层区域向左覆盖内容右侧。
const double kAnchorsPanelTotalWidth = 22 + 10 + 240;

/// 用户消息锚点数据：右侧导航条的一条横线。
///
/// [offset] 是消息顶部在内容坐标系中的偏移（精确缓存或估算），
/// 用于激活判定；[ratio] = offset / maxScrollExtent，用于绘制位置。
class UserAnchorData {
  const UserAnchorData({
    required this.msgId,
    required this.preview,
    required this.offset,
    this.ratio = 0,
  });

  final String msgId;

  /// 浮层/面板显示的消息预览文本
  final String preview;

  /// 消息顶部在内容坐标系中的偏移（0.0 = 列表开头）
  final double offset;

  /// offset / maxScrollExtent，0..1
  final double ratio;
}

/// 右侧悬浮锚点面板：
/// - 平时只绘制用户消息锚点（短横线），当前视口所在消息高亮
/// - hover 竖条展开浮层，列出全部用户消息预览，点击条目跳转到该消息
/// - 点击竖条任意位置 → 跳到最近的锚点（minimap 交互）
class MessageAnchorsPanel extends HookWidget {
  const MessageAnchorsPanel({
    super.key,
    required this.anchors,
    required this.activeMsgId,
    required this.onJumpTo,
  });

  final List<UserAnchorData> anchors;
  final ValueListenable<String?> activeMsgId;
  final void Function(String msgId) onJumpTo;

  static const double _barWidth = 22;
  static const double _panelWidth = 240;
  static const double _itemHeight = 44;
  static const int _closeDelayMs = 300;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final hovered = useState(false);
    final hoverY = useState(0.0);
    // 鼠标离开竖条后的关闭延迟：期间移入浮层则取消，
    // 保证 hover 区域只有竖条一窄条，浮层只是显示出来可点击
    final closeTimer = useRef<Timer?>(null);
    useEffect(
      () =>
          () => closeTimer.value?.cancel(),
      [],
    );

    void startCloseTimer() {
      closeTimer.value?.cancel();
      closeTimer.value = Timer(
        const Duration(milliseconds: _closeDelayMs),
        () => hovered.value = false,
      );
    }

    void cancelCloseTimer() {
      closeTimer.value?.cancel();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        final panelH = (anchors.length * _itemHeight).clamp(0.0, maxH);
        // 以鼠标位置为中心弹出；clamp 上下限为 0 / maxH - panelH，
        // 保证鼠标无论 hover 在竖条哪个高度，浮层都覆盖鼠标位置
        final top = (hoverY.value - panelH / 2).clamp(0.0, maxH - panelH);
        // 布局边界必须覆盖「竖条 + 间隙 + 浮层」整个区域：常规盒子的
        // hitTest 先用自身 bounds 过滤位置，浮层若溢出到边界之外，
        // 绘制可见但永远无法命中（点不到条目）。hover 语义仍只由
        // 竖条 MouseRegion 管理，浮层区域只是命中通道，不拦截。
        return SizedBox(
          width: kAnchorsPanelTotalWidth,
          height: maxH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── 竖条（右缘 22px）：hover 更新浮层位置；离开启动
              // 延迟关闭；点击任意位置跳到最近的锚点（minimap 交互）──
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: _barWidth,
                child: MouseRegion(
                  onEnter: (_) {
                    cancelCloseTimer();
                    hovered.value = true;
                  },
                  onExit: (_) => startCloseTimer(),
                  onHover: (event) => hoverY.value = event.localPosition.dy,
                  cursor: SystemMouseCursors.click,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) {
                      final usable = maxH - _anchorBarInnerPadding * 2;
                      if (usable <= 0 || anchors.isEmpty) return;
                      final y = event.localPosition.dy;
                      String? nearest;
                      var best = double.infinity;
                      for (final a in anchors) {
                        final ay =
                            _anchorBarInnerPadding +
                            a.ratio.clamp(0.0, 1.0) * usable;
                        final d = (ay - y).abs();
                        if (d < best) {
                          best = d;
                          nearest = a.msgId;
                        }
                      }
                      if (nearest != null) onJumpTo(nearest);
                    },
                    child: ValueListenableBuilder<String?>(
                      valueListenable: activeMsgId,
                      builder: (context, active, _) {
                        // SizedBox.expand 撑满 loose 高度约束：CustomPaint
                        // 无 child 时默认取 constraints.smallest（高度 0），
                        // 会导致 paint 永不执行
                        return CustomPaint(
                          painter: _AnchorBarPainter(
                            anchors: anchors,
                            activeMsgId: active,
                            activeColor: custom.colors.accent,
                            inactiveColor: custom.colors.textSecondary
                                .withValues(alpha: 0.55),
                          ),
                          child: const SizedBox.expand(),
                        );
                      },
                    ),
                  ),
                ),
              ),
              // ── hover 浮层：全部用户消息预览。自身 MouseRegion
              // 取消/启动延迟关闭 ──
              if (hovered.value && anchors.isNotEmpty)
                Positioned(
                  left: 0,
                  top: top,
                  width: _panelWidth,
                  height: panelH,
                  child: MouseRegion(
                    onEnter: (_) => cancelCloseTimer(),
                    onExit: (_) => startCloseTimer(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: custom.colors.panel,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: custom.colors.hover),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ValueListenableBuilder<String?>(
                        valueListenable: activeMsgId,
                        builder: (context, active, _) {
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: anchors.length,
                            itemBuilder: (context, i) {
                              final a = anchors[i];
                              final isActive = a.msgId == active;
                              return InkWell(
                                onTap: () {
                                  hovered.value = false;
                                  onJumpTo(a.msgId);
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  color: isActive
                                      ? custom.colors.selected
                                      : Colors.transparent,
                                  child: Text(
                                    a.preview,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: custom.typography.styleForSize(
                                      custom.typography.captionSize,
                                      isActive
                                          ? custom.colors.textPrimary
                                          : custom.colors.textSecondary,
                                      weight: isActive
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AnchorBarPainter extends CustomPainter {
  const _AnchorBarPainter({
    required this.anchors,
    required this.activeMsgId,
    required this.activeColor,
    required this.inactiveColor,
  });

  final List<UserAnchorData> anchors;
  final String? activeMsgId;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= _anchorBarInnerPadding * 2) return;
    final usable = size.height - _anchorBarInnerPadding * 2;
    for (final a in anchors) {
      final isActive = a.msgId == activeMsgId;
      final y = _anchorBarInnerPadding + a.ratio.clamp(0.0, 1.0) * usable;
      final paint = Paint()
        ..color = isActive ? activeColor : inactiveColor
        ..strokeWidth = isActive ? 4 : 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(5, y), Offset(size.width - 5, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnchorBarPainter oldDelegate) {
    return oldDelegate.anchors != anchors ||
        oldDelegate.activeMsgId != activeMsgId ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}

const double _anchorBarInnerPadding = 8;
