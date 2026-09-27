import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/utils/platform.dart';

/// 用户消息锚点数据：右侧导航条的一行。
///
/// [offset] 是消息顶部在内容坐标系中的偏移（精确缓存或估算），
/// 用于激活判定；[preview] 在展开后面板中展示。
class UserAnchorData {
  const UserAnchorData({
    required this.msgId,
    required this.preview,
    required this.offset,
    this.ratio = 0,
  });

  final String msgId;

  /// 面板显示的消息预览文本
  final String preview;

  /// 消息顶部在内容坐标系中的偏移（0.0 = 列表开头）
  final double offset;

  /// offset / maxScrollExtent，0..1
  final double ratio;
}

/// 右侧悬浮锚点面板（参考常见聊天的「限高滚动」竖条）：
/// - 平时只显示窄窄一条，右侧露出所有用户消息的短横线，垂直居中紧凑排布
/// - 桌面 hover / 手机点击后横向展开，露出左侧预览文字 + 右侧横线，激活项高亮
/// - 最大高度为屏高一半，超出部分内部滚动
/// - 点击某一行 → 跳转到该消息
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

  static const double _barWidth = 20;
  static const double _panelWidth = 240;
  static const double _itemHeight = 24;
  static const int _closeDelayMs = 300;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final mobile = isMobilePlatform;
    final hovered = useState(false);
    // 手机模式：无 hover，改为点击展开/收起
    final sheetOpen = useState(false);
    final closeTimer = useRef<Timer?>(null);
    useEffect(
      () => () => closeTimer.value?.cancel(),
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

    if (anchors.isEmpty) return const SizedBox.shrink();

    // 展开态：桌面靠 hover，手机靠点击
    final expanded = mobile ? sheetOpen.value : hovered.value;
    final panelW = expanded ? _panelWidth : _barWidth;
    // 最大高度：屏高一半，超出内部滚动（对应 max-height: 50vh + overflow-y）
    final maxPanelH = MediaQuery.sizeOf(context).height * 0.5;
    // 内容高度：行数*行高 + 上下内边距。显式给到面板，确保它贴合内容高度
    //（而非由 SingleChildScrollView 撑满可用高度），超过屏高一半才滚动。
    final contentH = anchors.length * _itemHeight + 20;
    final panelH = math.min(contentH, maxPanelH);

    // 竖条本体：默认窄条，hover（桌面）/ 点击（手机）展开成面板。
    // 高度贴合内容（panelH），避免撑起整个聊天区高度。
    final bar = MouseRegion(
      onEnter: (_) {
        cancelCloseTimer();
        hovered.value = true;
      },
      onExit: (_) => startCloseTimer(),
      cursor: SystemMouseCursors.click,
      child: Container(
        width: panelW,
        height: panelH,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: expanded ? custom.colors.panel : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: expanded ? Border.all(color: custom.colors.hover) : null,
          boxShadow: expanded
              ? const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxPanelH),
          child: ValueListenableBuilder<String?>(
            valueListenable: activeMsgId,
            builder: (context, active, _) {
              return SingleChildScrollView(
                clipBehavior: Clip.hardEdge,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final a in anchors)
                      _AnchorRow(
                        preview: a.preview,
                        isActive: a.msgId == active,
                        expanded: expanded,
                        custom: custom,
                        onTap: () {
                          if (mobile) sheetOpen.value = false;
                          hovered.value = false;
                          onJumpTo(a.msgId);
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    // 桌面：仅竖条本身响应 hover（展开面板），不影响聊天区滚动。
    if (!mobile) return bar;

    // 手机：右侧整条（延伸到聊天区域高度）都可以点击展开面板。
    // 竖条垂直居中于该条内，条其余部分透明、仅作为更大的点击热区。
    // 注意：宽度必须钳制为条宽（panelW），否则 Align(center) 会把宽度撑满整个
    // 父区域、把竖条水平居中到屏幕中间去。
    return SizedBox(
      width: panelW,
      height: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => sheetOpen.value = !sheetOpen.value,
        child: Align(
          alignment: Alignment.center,
          child: bar,
        ),
      ),
    );
  }
}

/// 竖条中的一行：左侧预览文字（展开才显示）+ 右侧短横线。
class _AnchorRow extends StatelessWidget {
  const _AnchorRow({
    required this.preview,
    required this.isActive,
    required this.expanded,
    required this.custom,
    required this.onTap,
  });

  final String preview;
  final bool isActive;
  final bool expanded;
  final CustomTheme custom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = isActive
        ? custom.colors.accent
        : custom.colors.textSecondary.withValues(alpha: 0.7);
    final textColor = isActive
        ? custom.colors.textPrimary
        : custom.colors.textSecondary;

    // 收起（窄条）时行不可见也不可命中：避免不可见的 InkWell 抢走点击，
    // 否则手机端点"小竖条"无法触发外层热区弹出面板。
    // 仅展开时才可点击跳转。
    return IgnorePointer(
      ignoring: !expanded,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: MessageAnchorsPanel._itemHeight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 左侧预览文字：窄条时透明，展开时显示
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: custom.typography.styleForSize(
                      custom.typography.captionSize,
                      textColor,
                      weight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
              // 右侧短横线
              Container(
                width: 12,
                height: 2,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? custom.colors.accent
                      : (expanded
                          ? custom.colors.textSecondary
                          : color),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}