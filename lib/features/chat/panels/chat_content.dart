import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:agent/rust_bridge/api/types.dart' as api;
import 'package:agent/services/session/part_types.dart';
import 'package:agent/store/config_store.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/utils/layout_utils.dart' show readingWidth;
import 'package:agent/widgets/divider/app_divider.dart';
import 'package:agent/features/chat/chat_input.dart';
import 'package:agent/features/chat/widgets/chat_message_item.dart';
import 'package:agent/features/chat/widgets/message_queue_panel.dart';
import 'package:agent/widgets/loading/app_loading.dart';

/// 保持底部用户在流式输出时始终在底部。
/// 非 reverse 列表下，内容向下生长不影响离开底部的用户。
class _KeepAtBottomPhysics extends ScrollPhysics {
  /// onBeforeEmit 时保存的 maxScrollExtent
  final double? savedMaxExtent;

  const _KeepAtBottomPhysics({super.parent, this.savedMaxExtent});

  @override
  _KeepAtBottomPhysics applyTo(ScrollPhysics? ancestor) {
    return _KeepAtBottomPhysics(
      parent: buildParent(ancestor),
      savedMaxExtent: savedMaxExtent,
    );
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    if (savedMaxExtent != null) {
      final growth = newPosition.maxScrollExtent - savedMaxExtent!;
      if (growth.abs() > 0) {
        // 用户在底部 → 滚到新底部
        return newPosition.maxScrollExtent;
      }
    }
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }
}

const double _listBottomSpacing = 40;

/// 拍平列表 item：用户消息整条 / assistant 单个 part。
/// 全部消息按此拍平后，消息列表只在视口内构建 item（列表级虚拟化）。
sealed class _FlatItem {
  const _FlatItem();
}

/// 整条消息一个 item（用户消息：编辑卡片需要全部 parts 一起渲染）
final class _FlatMessageItem extends _FlatItem {
  const _FlatMessageItem(this.msgIndex);

  final int msgIndex;
}

/// assistant 消息的单个 part
final class _FlatPartItem extends _FlatItem {
  const _FlatPartItem(this.msgIndex, this.partIndex);

  final int msgIndex;
  final int partIndex;
}

class _StreamingMessage extends StatelessWidget {
  final Widget child;

  const _StreamingMessage({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 20), child: child),
        const Positioned(left: 16, bottom: 0, child: AppLoading()),
      ],
    );
  }
}

class _StandaloneStreamingIndicator extends StatelessWidget {
  const _StandaloneStreamingIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      child: Stack(
        children: [Positioned(left: 16, bottom: 0, child: AppLoading())],
      ),
    );
  }
}

/// 与 [ChatMessageItem] 的可见性规则一致：不可见的 part 在拍平时直接
/// 跳过，避免渲染成 SizedBox.shrink 后仍占位产生幻影间距。
bool _isPartVisible(api.PartInfo part) {
  if (part.partType == PartTypes.toolResult) return false;
  // 工具返回的图片消息：仅模型上下文可见，前端不渲染
  if (part.partType == PartTypes.toolImage) return false;
  if (part.partType == PartTypes.text) {
    return part.content.isNotEmpty;
  }
  if (part.partType == PartTypes.reasoning) {
    return part.content.isNotEmpty;
  }
  if (part.partType == PartTypes.webSearch) {
    return part.content.isNotEmpty;
  }
  if (part.partType == PartTypes.subAgentText) {
    return part.content.isNotEmpty;
  }
  if (part.partType == PartTypes.image) {
    return part.content.isNotEmpty;
  }
  // tool_call / tool_call_frag 是同一个调用生命周期内的两种状态，都展示
  return part.partType == PartTypes.toolCall ||
      part.partType == PartTypes.toolCallFrag;
}

/// 聊天内容区 — 消息列表 + 队列面板 + 输入框
///
/// 流式输出中按 Enter 发送的消息自动进入队列，
/// 当前回复结束后自动发出。
class ChatContent extends StatelessWidget {
  const ChatContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
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
              Expanded(child: _MessageList(sessionId: displayId)),
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: readingWidth,
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
              height: maxH.isFinite ? maxH : MediaQuery.sizeOf(context).height,
              child: ChatInput(fullHeight: true),
            );
          },
        );
      },
    );
  }
}

/// 消息列表 — ListView 非 reverse，流式内容向下生长
class _MessageList extends StatelessWidget {
  final String sessionId;

  const _MessageList({required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (_) {
        final mgr = SessionStore.instance;
        final sessionState = mgr.sessions.value[sessionId];
        if (sessionState == null) return const SizedBox.shrink();

        final messageOrder = sessionState.messageOrder;
        final partsByMsg = sessionState.partsByMsg;
        final messageRoles = sessionState.messageRoles;
        final messageModels = sessionState.messageModels;

        if (messageOrder.isEmpty) return const SizedBox.shrink();

        final isFirstInTurn = _computeFirstInTurn(messageOrder, messageRoles);

        final isStreaming = mgr.streamingSessionIds.value.contains(sessionId);
        final latestUserIndex = messageOrder.lastIndexWhere(
          (msgId) => messageRoles[msgId] == 'user',
        );

        return HookBuilder(
          key: ValueKey('msglist_$sessionId'),
          builder: (context) {
            final scrollController = useScrollController();
            final focusedMsgId = useState<String?>(null);
            final savedMaxExtent = useRef<double?>(null);
            // 用户是否贴底（流式跟随的条件）：滚动时实时更新，
            // 初始挂载后首次评估时惰性初始化（以实际位置为准）。
            final isPinnedRef = useRef<bool?>(null);

            // 监听滚动位置：更新贴底状态；离开底部时清空 physics 保留位
            useEffect(() {
              void onScroll() {
                if (!scrollController.hasClients) return;
                final pos = scrollController.position;
                // 视口底下没剩内容（== 0）即贴底
                isPinnedRef.value = pos.extentAfter <= 0;
                if (pos.extentAfter > 0) {
                  savedMaxExtent.value = null;
                }
              }

              scrollController.addListener(onScroll);
              return () => scrollController.removeListener(onScroll);
            }, [scrollController]);

            /// 直接跳到底部。ListView 懒加载时 maxScrollExtent 是估算值，
            /// 单次 jumpTo 可能到不了真实底部（差一小截），靠后续流式
            /// 触发的再次跳转逐步收敛。
            void jumpToBottom() {
              if (!scrollController.hasClients) return;
              final p = scrollController.position;
              scrollController.jumpTo(p.maxScrollExtent);
            }

            // 全部消息拍平到 item 粒度（见下方「全量拍平」），视口外的
            // item 由 ListView 跳过构建。若把整轮打包进单个 item
            // （旧 _LatestTurnLayout 方案），一轮内数百/上千个 parts（工具
            // 调用卡片等）每帧全量构建+布局，虚拟滚动完全失效 ——
            // 实测 1000 张卡片时每帧 ~140ms。拍平后视口外的卡片不构建。
            final focusedIndex = focusedMsgId.value == null
                ? -1
                : messageOrder.indexOf(focusedMsgId.value!);

            // ── 全量拍平 ──
            // 用户消息整条一个 item（编辑卡片需要全部 parts 一起渲染）；
            // assistant 消息按 part 拍平（列表只在视口内构建 item）。
            final hasLatestTurn = latestUserIndex >= 0;
            final flatItems = <_FlatItem>[];
            for (var m = 0; m < messageOrder.length; m++) {
              final msgId = messageOrder[m];
              final parts = partsByMsg[msgId] ?? [];
              // 纯工具类消息不占位
              if (parts.isNotEmpty && PartTypes.isToolOnly(parts)) continue;
              // 用户消息整条渲染（编辑/重试卡片）
              if (messageRoles[msgId] == 'user') {
                flatItems.add(_FlatMessageItem(m));
                continue;
              }
              for (var p = 0; p < parts.length; p++) {
                final part = parts[p];
                // 不可见 part（toolResult/toolImage/空内容）不占位，
                // 避免渲染成 SizedBox.shrink 后仍留下 8px 幻影间距
                if (!_isPartVisible(part)) continue;
                flatItems.add(_FlatPartItem(m, p));
              }
            }
            // 最新轮只有用户消息（无任何 assistant 内容）时，末尾显示独立 loading
            final standaloneIndicator =
                hasLatestTurn &&
                isStreaming &&
                latestUserIndex == messageOrder.length - 1;
            final itemCount = flatItems.length + (standaloneIndicator ? 1 : 0);

            // ── 新消息/流式：itemCount 变化时滚到底部 ──
            // 切换会话后首次构建不跳底（停留在对话顶部），只有 itemCount
            // 真正变化（新消息/流式新 part）才跳。
            final lastItemCount = useRef(itemCount);
            useEffect(() {
              final prevItemCount = lastItemCount.value;
              lastItemCount.value = itemCount;
              // 初始挂载（切换会话后首次构建）不跳底
              if (prevItemCount == itemCount) return null;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!scrollController.hasClients) return;
                // 首次评估以实际位置为准（新会话从顶部开始 → 不贴底 → 不跳）
                isPinnedRef.value ??=
                    scrollController.position.extentAfter <= 0;
                // 贴底才跟随：用户在中间翻历史时不拽回底部
                if (isPinnedRef.value != true) return;
                jumpToBottom();
              });
              return null;
            }, [itemCount]);

            // 流式输出中，用户在底部则保存 maxScrollExtent 供 physics 使用
            useEffect(() {
              final mgr = SessionStore.instance;
              mgr.onBeforeEmit = () {
                if (!scrollController.hasClients) return;
                final streaming = mgr.streamingSessionIds.value.contains(
                  sessionId,
                );
                if (!streaming) {
                  savedMaxExtent.value = null;
                  return;
                }
                if (scrollController.position.extentAfter <= 0) {
                  savedMaxExtent.value =
                      scrollController.position.maxScrollExtent;
                  // 文本增长（无新 part，itemCount 不变不触发 jumpTo）时，
                  // 若懒加载估算偏差把最新内容/loading 推出视口，
                  // 下一帧收敛跳底恢复贴底。仅在用户贴底时安排，
                  // 用户滚动离开底部后（extentAfter > 0）不再打扰。
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!scrollController.hasClients) return;
                    if (scrollController.position.extentAfter > 0) {
                      jumpToBottom();
                    }
                  });
                }
              };
              return () {
                SessionStore.instance.onBeforeEmit = null;
              };
            }, [sessionId, scrollController]);

            /// 包裹拍平 item：part 间距、流式 loading、底部间距
            /// 所有 part（含跨消息）间距统一：两侧 messagePadding xs(4)
            /// 合计 8px，不做消息/part 分层，保证视觉完全一致。
            Widget wrapFlatItem(
              Widget item, {
              required bool isLastItem,
              // 用户消息不挂 loading（由独立流式指示器负责），避免
              // loading 出现/消失导致用户消息子树反复重建
              bool showStreamingLoading = true,
            }) {
              if (isLastItem) {
                // 先包 _StreamingMessage（loading 距内容 20px，与历史结构一致），
                // 再包底部间距 —— 顺序反了会把 loading 推到内容下方 60px 处
                if (isStreaming && showStreamingLoading) {
                  item = _StreamingMessage(child: item);
                }
                item = Padding(
                  padding: const EdgeInsets.only(bottom: _listBottomSpacing),
                  child: item,
                );
              }
              return item;
            }

            /// 整条消息一个 item（用户消息：编辑/重试卡片需要全部 parts）
            Widget buildMessageItem(int msgIndex, {required bool isLastItem}) {
              final msgId = messageOrder[msgIndex];
              final parts = partsByMsg[msgId] ?? [];
              final messageItem = ChatMessageItem(
                key: ValueKey(msgId),
                sessionId: sessionId,
                msgId: msgId,
                role: messageRoles[msgId] ?? '',
                parts: parts,
                // 历史消息（含用户消息）一律静态渲染：streaming
                // 只对正在流式的 assistant 消息（buildPartItem）生效。
                // 若按会话级 isStreaming 传值，每次发送新消息都会让全部
                // 历史消息切到流式模式 —— Streamdown 重建管线后异步重放
                // 全文，产生 1-2 帧空白，表现为发送时界面闪烁。
                streaming: false,
                modelName: isFirstInTurn[msgIndex] == true
                    ? messageModels[msgId]
                    : null,
                dimmed: focusedIndex >= 0 && msgIndex > focusedIndex,
                onFocusChanged: (focused) {
                  focusedMsgId.value = focused ? msgId : null;
                },
                onRetry: (msgId, newContent, imagePaths, imageNames) {
                  final mgr = SessionStore.instance;
                  mgr.retryMessage(
                    sessionId: sessionId,
                    msgId: msgId,
                    newPrompt: newContent,
                    provider: ConfigStore.instance.currentProvider.value,
                    model: ConfigStore.instance.currentModel.value,
                    imagePaths: imagePaths,
                    imageNames: imageNames,
                  );
                },
              );
              return wrapFlatItem(
                messageItem,
                isLastItem: isLastItem,
                // 用户消息不挂流式 loading（原设计：loading 指示器
                // 不挂在用户消息上，由独立指示器/最后一条内容项负责）
                showStreamingLoading: false,
              );
            }

            /// assistant 消息拍平后的单个 part 项（视口外的 part 由
            /// ListView 跳过构建 —— part 级虚拟化）
            Widget buildPartItem(
              int msgIndex,
              int partIndex, {
              required bool isLastItem,
            }) {
              final msgId = messageOrder[msgIndex];
              final parts = partsByMsg[msgId] ?? [];
              if (partIndex >= parts.length) return const SizedBox.shrink();
              final part = parts[partIndex];
              Widget item = ChatMessageItem(
                key: ValueKey('${msgId}_${part.id}'),
                sessionId: sessionId,
                msgId: msgId,
                role: messageRoles[msgId] ?? '',
                parts: [part],
                // 仅最新轮的 assistant 消息流式渲染
                streaming:
                    hasLatestTurn && msgIndex > latestUserIndex && isStreaming,
                modelName: partIndex == 0 && isFirstInTurn[msgIndex] == true
                    ? messageModels[msgId]
                    : null,
                dimmed: focusedIndex >= 0 && msgIndex > focusedIndex,
                onFocusChanged: (focused) {
                  focusedMsgId.value = focused ? msgId : null;
                },
                onRetry: (msgId, newContent, imagePaths, imageNames) {
                  final mgr = SessionStore.instance;
                  mgr.retryMessage(
                    sessionId: sessionId,
                    msgId: msgId,
                    newPrompt: newContent,
                    provider: ConfigStore.instance.currentProvider.value,
                    model: ConfigStore.instance.currentModel.value,
                    imagePaths: imagePaths,
                    imageNames: imageNames,
                  );
                },
              );
              return wrapFlatItem(item, isLastItem: isLastItem);
            }

            final listView = ListView.builder(
              controller: scrollController,
              physics: savedMaxExtent.value != null
                  ? _KeepAtBottomPhysics(savedMaxExtent: savedMaxExtent.value)
                  : null,
              padding: EdgeInsets.only(
                top: 0,
                bottom: hasLatestTurn ? 0 : _listBottomSpacing,
              ),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                // 独立流式指示器（最新一轮只有用户消息，无 assistant 内容）
                if (index >= flatItems.length) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: _listBottomSpacing),
                    child: _StandaloneStreamingIndicator(),
                  );
                }
                final item = flatItems[index];
                final isLastItem = index == itemCount - 1;
                return switch (item) {
                  _FlatMessageItem(:final msgIndex) => buildMessageItem(
                    msgIndex,
                    isLastItem: isLastItem,
                  ),
                  _FlatPartItem(:final msgIndex, :final partIndex) =>
                    buildPartItem(msgIndex, partIndex, isLastItem: isLastItem),
                };
              },
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: readingWidth,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      child: listView,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  List<bool> _computeFirstInTurn(
    List<String> messageOrder,
    Map<String, String> messageRoles,
  ) {
    final result = List<bool>.filled(messageOrder.length, false);
    bool waitingForAssistant = true;
    for (int i = 0; i < messageOrder.length; i++) {
      final role = messageRoles[messageOrder[i]];
      if (role == 'user') {
        waitingForAssistant = true;
      } else if (role == 'assistant' && waitingForAssistant) {
        result[i] = true;
        waitingForAssistant = false;
      }
    }
    return result;
  }
}
