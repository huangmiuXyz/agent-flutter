import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/services/llm/llm_providers.dart';
import 'package:agent/services/session/session_manager.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/divider/app_divider.dart';
import 'package:agent/features/chat/chat_input.dart';
import 'package:agent/features/chat/widgets/chat_message_item.dart';
import 'package:agent/widgets/loading/app_loading.dart';

/// 聊天内容区 — 消息列表（非 reverse ListView）+ 输入框
class ChatContent extends StatelessWidget {
  const ChatContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SignalBuilder(
            builder: (_) {
              final selectedId = SessionManager.instance.selectedId.value;
              return selectedId != null
                  ? _MessageList(sessionId: selectedId)
                  : const SizedBox.shrink();
            },
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
        final mgr = SessionManager.instance;
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
          builder: (context) {
            final scrollController = useScrollController();
            final focusedMsgId = useState<String?>(null);
            final isNearBottom = useRef(true);

            // 监听滚动位置判断是否在底部
            useEffect(() {
              void onScroll() {
                if (!scrollController.hasClients) return;
                isNearBottom.value =
                    scrollController.position.extentAfter <= 100;
              }

              scrollController.addListener(onScroll);
              return () => scrollController.removeListener(onScroll);
            }, [scrollController]);

            // 初始滚到底部
            useEffect(() {
              if (!scrollController.hasClients) return null;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!scrollController.hasClients) return;
                scrollController.jumpTo(
                  scrollController.position.maxScrollExtent,
                );
              });
              return null;
            }, [sessionId, messageOrder.length]);

            // 流式输出时，在底部则自动跟随
            useEffect(() {
              final mgr = SessionManager.instance;
              mgr.onBeforeEmit = () {
                if (!scrollController.hasClients) return;
                final streaming = mgr.streamingSessionIds.value.contains(
                  sessionId,
                );
                if (!streaming) return;

                if (isNearBottom.value) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!scrollController.hasClients) return;
                    scrollController.jumpTo(
                      scrollController.position.maxScrollExtent,
                    );
                  });
                }
              };
              return () {
                SessionManager.instance.onBeforeEmit = null;
              };
            }, [sessionId, scrollController]);

            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: _readingWidth(),
                child: ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.only(top: custom.spacing.sm, bottom: 40),
                  itemCount: messageOrder.length + (isStreaming ? 1 : 0),
                  itemBuilder: (context, index) {
                    // 流式加载指示器在列表末尾
                    if (isStreaming && index == messageOrder.length) {
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          custom.spacing.md,
                          custom.spacing.xs,
                          custom.spacing.md,
                          custom.spacing.sm,
                        ),
                        child: const AppLoading(),
                      );
                    }

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

                    return ChatMessageItem(
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
                        final f = ProviderScope.containerOf(context);
                        final mgr = SessionManager.instance;
                        final currentProvider = f.read(currentProviderProvider);
                        final currentModel = f.read(currentModelProvider);
                        mgr.retryMessage(
                          sessionId: sessionId,
                          msgId: msgId,
                          newPrompt: newContent,
                          provider: currentProvider,
                          model: currentModel,
                          service: f.read(llmServiceProvider),
                          dbPath: f.read(dbPathProvider),
                          configPath: f.read(configPathProvider),
                        );
                      },
                    );
                  },
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
