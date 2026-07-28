import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/store/config_store.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/custom_theme.dart';
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

/// 聊天内容区 — 消息列表 + 队列面板 + 输入框
///
/// 流式输出中按 Enter 发送的消息自动进入队列，
/// 当前回复结束后自动发出。
class ChatContent extends StatelessWidget {
  const ChatContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SignalBuilder(
            builder: (_) {
              final displayId = SessionStore.instance.displayedSessionId.value;
              return displayId != null
                  ? _MessageList(sessionId: displayId)
                  : const SizedBox.shrink();
            },
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: _readingWidth(),
            child: const MessageQueuePanel(),
          ),
        ),
        const AppDivider(extent: 1, thickness: 1),
        const ChatInput(),
      ],
    );
  }
}

/// 消息列表 — ListView 非 reverse，流式内容向下生长
class _MessageList extends StatelessWidget {
  final String sessionId;

  const _MessageList({required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return SignalBuilder(
      builder: (_) {
        final mgr = SessionStore.instance;
        final sessionState = mgr.sessions.value[sessionId];
        if (sessionState == null) return const SizedBox.shrink();

        final messageOrder = sessionState.messageOrder;
        final partsByMsg = sessionState.partsByMsg;
        final messageRoles = sessionState.messageRoles;
        final messageModels = sessionState.messageModels;

        final toolCallResults = _buildToolCallResults(partsByMsg);

        if (messageOrder.isEmpty) return const SizedBox.shrink();

        final lastExpandableMsgIndex = _lastExpandableMessageIndex(
          messageOrder,
          partsByMsg,
          messageRoles,
        );
        final isFirstInTurn = _computeFirstInTurn(messageOrder, messageRoles);

        final isStreaming = mgr.streamingSessionIds.value.contains(sessionId);

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

            // ── 切换 session：先隐藏 → jumpTo 底部 → 再显示 ──
            useEffect(() {
              isListVisible.value = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!scrollController.hasClients) return;
                scrollController.jumpTo(
                  scrollController.position.maxScrollExtent,
                );
                isListVisible.value = true;
              });
              return null;
            }, [sessionId]);

            // ── 新消息/流式：只滚动到底部，不隐藏 ──
            useEffect(() {
              if (!isListVisible.value) return null;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!scrollController.hasClients) return;
                scrollController.jumpTo(
                  scrollController.position.maxScrollExtent,
                );
              });
              return null;
            }, [messageOrder.length]);

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
                }
              };
              return () {
                SessionStore.instance.onBeforeEmit = null;
              };
            }, [sessionId, scrollController]);

            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: _readingWidth(),
                child: Opacity(
                  opacity: isListVisible.value ? 1.0 : 0.0,
                  child: ListView.builder(
                    controller: scrollController,
                    physics: savedMaxExtent.value != null
                        ? _KeepAtBottomPhysics(
                            savedMaxExtent: savedMaxExtent.value,
                          )
                        : null,
                    padding: EdgeInsets.only(
                      top: custom.spacing.sm,
                      bottom: 40,
                    ),
                    itemCount: messageOrder.length,
                    itemBuilder: (context, index) {
                      final msgId = messageOrder[index];
                      final parts = partsByMsg[msgId] ?? [];
                      final role = messageRoles[msgId] ?? '';

                      // 纯工具类消息不占位
                      if (parts.isNotEmpty &&
                          parts.every(
                            (p) =>
                                p.partType == 'tool_result' ||
                                p.partType == 'tool_call_frag',
                          )) {
                        return const SizedBox.shrink();
                      }

                      final dimmed =
                          focusedMsgId.value != null &&
                          index > messageOrder.indexOf(focusedMsgId.value!);

                      final messageItem = ChatMessageItem(
                        key: ValueKey(msgId),
                        sessionId: sessionId,
                        msgId: msgId,
                        role: role,
                        parts: parts,
                        streaming: isStreaming,
                        toolCallResults: toolCallResults,
                        autoExpandLast: index == lastExpandableMsgIndex,
                        modelName: isFirstInTurn[index] == true
                            ? messageModels[msgId]
                            : null,
                        dimmed: dimmed,
                        onFocusChanged: (focused) {
                          focusedMsgId.value = focused ? msgId : null;
                        },
                        onRetry: (msgId, newContent) {
                          final mgr = SessionStore.instance;
                          mgr.retryMessage(
                            sessionId: sessionId,
                            msgId: msgId,
                            newPrompt: newContent,
                            provider:
                                ConfigStore.instance.currentProvider.value,
                            model: ConfigStore.instance.currentModel.value,
                          );
                        },
                      );

                      // 流式输出中，最后一条消息下方显示 loading
                      if (isStreaming && index == messageOrder.length - 1) {
                        return Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: messageItem,
                            ),
                            const Positioned(
                              left: 16,
                              bottom: 0,
                              child: AppLoading(),
                            ),
                          ],
                        );
                      }

                      return messageItem;
                    },
                  ),
                ),
              ),
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

  int _lastExpandableMessageIndex(
    List<String> messageOrder,
    Map<String, List<api.PartInfo>> partsByMsg,
    Map<String, String> messageRoles,
  ) {
    for (int i = messageOrder.length - 1; i >= 0; i--) {
      final mId = messageOrder[i];
      final parts = partsByMsg[mId] ?? [];
      if (parts.isEmpty) continue;
      if (parts.every(
        (p) => p.partType == 'tool_result' || p.partType == 'tool_call_frag',
      )) {
        continue;
      }
      if (messageRoles[mId] == 'assistant' &&
          parts.any((p) => _isExpandablePartType(p.partType))) {
        return i;
      }
    }
    return -1;
  }

  bool _isExpandablePartType(String partType) {
    return partType == 'reasoning' ||
        partType == 'tool_call' ||
        partType == 'tool_call_frag';
  }

  Map<String, String> _buildToolCallResults(
    Map<String, List<api.PartInfo>> partsByMsg,
  ) {
    final results = <String, String>{};
    for (final parts in partsByMsg.values) {
      for (final part in parts) {
        if (part.partType == 'tool_result') {
          try {
            final json = jsonDecode(part.content) as Map<String, dynamic>;
            final toolCallId = json['tool_call_id'] as String?;
            if (toolCallId != null && toolCallId.isNotEmpty) {
              final resultContent = json['content'] as String?;
              results[toolCallId] =
                  (resultContent != null && resultContent.isNotEmpty)
                  ? resultContent
                  : part.content;
            }
          } catch (_) {}
        }
      }
    }
    return results;
  }
}

double _readingWidth() {
  final display = PlatformDispatcher.instance.displays.first;
  return display.size.width / display.devicePixelRatio / 2;
}
