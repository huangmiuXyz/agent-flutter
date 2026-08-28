// RenderEditableContainerBox 未从 fleather 公开导出；版本已在 pubspec.lock 锁定
// （fleather 1.27.0），内部路径引用可接受。
// ignore: implementation_imports
import 'package:fleather/src/rendering/editable_box.dart'
    show RenderEditableContainerBox;
import 'package:flutter/gestures.dart' show HitTestResult, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/chat/chat_fleather.dart';
import 'package:agent/features/chat/chat_input.dart';
import 'package:agent/features/chat/widgets/chat_message_item.dart';
import 'package:agent/features/chat/widgets/message_queue_panel.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/utils/layout_utils.dart' show readingWidthFor;
import 'package:agent/widgets/divider/app_divider.dart';

import 'message_list.dart';

/// 聊天内容区 — 消息列表 + 队列面板 + 输入框
///
/// 流式输出中按 Enter 发送的消息自动进入队列，
/// 当前回复结束后自动发出。
class ChatContent extends HookWidget {
  const ChatContent({super.key});

  @override
  Widget build(BuildContext context) {
    // 点击空白取消焦点：用 Listener 而非 GestureDetector ——
    // assistant 文本的 SelectionArea（文本选择）会赢下 tap 竞技场，
    // GestureDetector.onTap 永远不会触发；Listener 不参与竞技场，
    // 任何点击都会走到这里。仅在满足以下条件时取消：
    //   1. pointer up 位移在 touch slop 内（非滚动/拖动）；
    //   2. 点击位置未命中可编辑组件（输入框/富文本编辑器）；
    //   3. 点击未落在 Fleather 编辑器内（chatFleatherPointerUp 内层标记）。
    final downPos = useRef<Offset?>(null);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        downPos.value = event.position;
        // 每次点击开始重置用户消息标记（点击卡片外空白仍正常取消焦点）
        userMessagePointerUp = false;
        // 每次点击开始重置 Fleather 编辑器标记（点击编辑器外空白仍正常取消焦点）
        chatFleatherPointerUp = false;
      },
      onPointerUp: (event) {
        final down = downPos.value;
        downPos.value = null;
        if (down == null) return;
        // 滚动/拖动（位移超过 touch slop）不取消，避免打断滚动
        if ((event.position - down).distance > kTouchSlop) return;
        // 点击了可编辑组件（输入框/编辑器）不取消，避免打断编辑。
        // 注意：Fleather 编辑器（用户消息 ChatFleather）的渲染对象是
        // `RenderEditableContainerBox` 而非 Flutter 的 `RenderEditable`，
        // 漏判会导致点击编辑框时被当作空白区域而 unfocus（点一下反而失焦）。
        // 该类型未从 fleather 公开导出，import 内部路径（版本已锁定）。
        // 但容器在点击文本行下方空白时同样不在 hit test 路径中（未重写
        // hitTestSelf），此处仅能兜底文本行命中；编辑器内空白区域的点击
        // 由 ChatFleather 内层 Listener 置位的 chatFleatherPointerUp 标记拦截。
        final result = HitTestResult();
        WidgetsBinding.instance.hitTestInView(
          result,
          event.position,
          event.viewId,
        );
        final hitEditable = result.path.any(
          (entry) =>
              entry.target is RenderEditable ||
              entry.target is RenderEditableContainerBox,
        );
        // 用户消息卡片整体（含空白/按钮）点击也不取消：
        // 卡片内层 Listener 已置位标记（pointer up 叶子→根分发，内层先执行）
        if (!hitEditable && !userMessagePointerUp && !chatFleatherPointerUp) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
        userMessagePointerUp = false; // 消费标记
        chatFleatherPointerUp = false; // 消费标记
      },
      child: SignalBuilder(
        builder: (_) {
          final displayId = SessionStore.instance.displayedSessionId.value;
          // 没有任何消息时输入框全屏显示（新会话/空会话）
          final hasMessages =
              displayId != null &&
              (SessionStore
                      .instance
                      .sessions
                      .value[displayId]
                      ?.messageOrder
                      .isNotEmpty ??
                  false);

          // 有消息时无需 LayoutBuilder（避免 resize 时级联重建），
          // 空会话时才需要 LayoutBuilder 获取 maxHeight 给全屏输入框
          if (hasMessages) {
            return Column(
              key: const ValueKey('chat_with_messages'),
              children: [
                Expanded(child: MessageList(sessionId: displayId)),
                Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: readingWidthFor(context),
                    child: const MessageQueuePanel(),
                  ),
                ),
                const AppDivider(extent: 1, thickness: 1),
                const SizedBox(
                  key: ValueKey('inputSlot'),
                  child: ChatInput(fullHeight: false),
                ),
              ],
            );
          }

          return LayoutBuilder(
            key: const ValueKey('chat_empty'),
            builder: (context, constraints) {
              final maxH = constraints.maxHeight;
              // 注：Column 的非 flex 子级主轴约束无界，因此全屏高度
              // 必须由这里显式给出，不能靠内部 Expanded 自动撑满。
              return SizedBox(
                key: const ValueKey('inputSlot'),
                height: maxH.isFinite
                    ? maxH
                    : MediaQuery.sizeOf(context).height,
                child: ChatInput(fullHeight: true),
              );
            },
          );
        },
      ),
    );
  }
}
