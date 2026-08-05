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
      if (growth.abs() > 0.5) {
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
              height: maxH.isFinite
                  ? maxH
                  : MediaQuery.sizeOf(context).height,
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
            // 切换 session 时：先隐藏 ListView → jumpTo 底部 → 再显示
            final isListVisible = useState(false);

            // 监听滚动位置，离开底部时清空 physics 保留位
            useEffect(() {
              void onScroll() {
                if (!scrollController.hasClients) return;
                if (scrollController.position.extentAfter > 0) {
                  savedMaxExtent.value = null;
                }
              }

              scrollController.addListener(onScroll);
              return () => scrollController.removeListener(onScroll);
            }, [scrollController]);

            /// 收敛式跳到底部：ListView 懒加载时 maxScrollExtent 是估算值
            /// （只基于已布局的 item），一次 jumpTo 到不了真实底部；
            /// 跳完后布局更新、估算值修正，递归再跳直到真正到底
            /// （extentAfter == 0）。这样最新内容（流式文本/新 part）
            /// 始终在视口内逐字渲染，而不是在视口外积累后整段出现。
            void jumpToBottomRecursive(int depth) {
              if (!scrollController.hasClients || depth <= 0) return;
              final p = scrollController.position;
              scrollController.jumpTo(p.maxScrollExtent);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!scrollController.hasClients) return;
                if (scrollController.position.extentAfter > 0.5) {
                  jumpToBottomRecursive(depth - 1);
                }
              });
            }

            // ── 切换 session：先隐藏 → 收敛跳到底部 → 再显示 ──
            useEffect(() {
              isListVisible.value = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                jumpToBottomRecursive(3);
                isListVisible.value = true;
              });
              return null;
            }, [sessionId]);
            // 让 ListView 在 part 粒度上虚拟化。若把整轮打包进单个 item
            // （旧 _LatestTurnLayout 方案），一轮内数百/上千个 parts（工具
            // 调用卡片等）每帧全量构建+布局，虚拟滚动完全失效 ——
            // 实测 1000 张卡片时每帧 ~140ms。拍平后视口外的卡片不构建。
            final focusedIndex = focusedMsgId.value == null
                ? -1
                : messageOrder.indexOf(focusedMsgId.value!);

            final hasLatestTurn = latestUserIndex >= 0;
            final flattenedParts = hasLatestTurn
                ? <(int, int)>[
                    for (int m = latestUserIndex + 1;
                        m < messageOrder.length;
                        m++)
                      for (int p = 0;
                          p < (partsByMsg[messageOrder[m]]?.length ?? 0);
                          p++)
                        (m, p),
                  ]
                : const <(int, int)>[];
            // 最新一轮只有用户消息（无任何 assistant 内容）时，末尾显示独立 loading
            final standaloneIndicator = hasLatestTurn &&
                isStreaming &&
                latestUserIndex == messageOrder.length - 1;
            final itemCount = !hasLatestTurn
                ? messageOrder.length
                : latestUserIndex +
                    1 +
                    flattenedParts.length +
                    (standaloneIndicator ? 1 : 0);

            // ── 新消息/流式：只滚动到底部，不隐藏 ──
            useEffect(() {
              if (!isListVisible.value) return null;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                jumpToBottomRecursive(3);
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
                    if (scrollController.position.extentAfter > 0.5) {
                      jumpToBottomRecursive(2);
                    }
                  });
                }
              };
              return () {
                SessionStore.instance.onBeforeEmit = null;
              };
            }, [sessionId, scrollController]);

            Widget buildMessage(
              int index, {
              bool showStreamingIndicator = true,
            }) {
              final msgId = messageOrder[index];
              final parts = partsByMsg[msgId] ?? [];
              final role = messageRoles[msgId] ?? '';

              // 纯工具类消息不占位
              if (parts.isNotEmpty && PartTypes.isToolOnly(parts)) {
                return const SizedBox.shrink();
              }

              final messageItem = ChatMessageItem(
                key: ValueKey(msgId),
                sessionId: sessionId,
                msgId: msgId,
                role: role,
                parts: parts,
                // 历史消息（含最新轮的用户消息）一律静态渲染：streaming
                // 只对正在流式的 assistant 消息（buildFlattenedPartItem）
                // 生效。若按会话级 isStreaming 传值，每次发送新消息都会
                // 让全部历史消息切到流式模式 —— Streamdown 重建管线后
                // 异步重放全文，产生 1-2 帧空白，表现为发送时界面闪烁。
                streaming: false,
                modelName: isFirstInTurn[index] == true
                    ? messageModels[msgId]
                    : null,
                dimmed: focusedIndex >= 0 && index > focusedIndex,
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

              // 流式输出中，最后一条消息下方显示 loading
              if (showStreamingIndicator &&
                  isStreaming &&
                  index == messageOrder.length - 1) {
                return _StreamingMessage(child: messageItem);
              }

              return messageItem;
            }

            /// 最新轮拍平后的单个 part 项（视口外的 part 由 ListView 跳过构建）
            Widget buildFlattenedPartItem(
              int msgIndex,
              api.PartInfo part, {
              required bool isFirstPartOfMsg,
              required bool isLastItem,
            }) {
              final msgId = messageOrder[msgIndex];
              final role = messageRoles[msgId] ?? '';
              Widget item = ChatMessageItem(
                key: ValueKey('${msgId}_${part.id}'),
                sessionId: sessionId,
                msgId: msgId,
                role: role,
                parts: [part],
                streaming: isStreaming,
                modelName: isFirstPartOfMsg ? messageModels[msgId] : null,
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
              if (isLastItem) {
                // 先包 _StreamingMessage（loading 距内容 20px，与历史结构一致），
                // 再包底部间距 —— 顺序反了会把 loading 推到内容下方 60px 处
                if (isStreaming) {
                  item = _StreamingMessage(child: item);
                }
                item = Padding(
                  padding: const EdgeInsets.only(bottom: _listBottomSpacing),
                  child: item,
                );
              }
              return item;
            }

            final listView = ListView.builder(
              controller: scrollController,
              physics: savedMaxExtent.value != null
                  ? _KeepAtBottomPhysics(
                      savedMaxExtent: savedMaxExtent.value,
                    )
                  : null,
              padding: EdgeInsets.only(
                top: 0,
                bottom: hasLatestTurn ? 0 : _listBottomSpacing,
              ),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                // 最新轮之前的历史消息：消息级 item
                if (!hasLatestTurn || index < latestUserIndex) {
                  return buildMessage(index);
                }
                // 最新轮的用户消息：单独 item（loading 指示器不挂在用户消息上）
                if (index == latestUserIndex) {
                  return buildMessage(
                    latestUserIndex,
                    showStreamingIndicator: false,
                  );
                }
                // 最新轮的 assistant parts：拍平后每个 part 一个 item，
                // ListView 只构建视口内（+cacheExtent）的部分 —— part 级虚拟化
                final flatIdx = index - latestUserIndex - 1;
                if (flatIdx < flattenedParts.length) {
                  final (msgIndex, partIndex) = flattenedParts[flatIdx];
                  final part = partsByMsg[messageOrder[msgIndex]]![partIndex];
                  return buildFlattenedPartItem(
                    msgIndex,
                    part,
                    isFirstPartOfMsg: partIndex == 0,
                    isLastItem: index == itemCount - 1,
                  );
                }
                // 独立流式指示器（最新一轮只有用户消息，无 assistant 内容）
                return const Padding(
                  padding: EdgeInsets.only(bottom: _listBottomSpacing),
                  child: _StandaloneStreamingIndicator(),
                );
              },
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: readingWidth,
                    child: Opacity(
                      opacity: isListVisible.value ? 1.0 : 0.0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        child: listView,
                      ),
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
