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

/// 聊天内容区 — 消息列表（虚拟滚动）+ 输入框
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

/// 消息列表 — 只监听结构变更，流式更新穿透到单个消息组件
class _MessageList extends StatelessWidget {
  final String sessionId;

  const _MessageList({required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    // SignalBuilder 自动追踪 inside 读取的信号。
    // 读取 sessions 使本组件在结构变更时重建。
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

        // 找出全局最后一个有 expandable part 的消息索引
        final lastExpandableMsgIndex = _lastExpandableMessageIndex(
          messageOrder, partsByMsg, messageRoles,
        );
        // 预计算每条消息是否是轮次中的第一条 assistant（用于显示模型信息）
        final isFirstInTurn = _computeFirstInTurn(messageOrder, messageRoles);

        final isStreaming = mgr.streamingSessionIds.value.contains(sessionId);

        return HookBuilder(
          builder: (context) {
            final scrollController = useScrollController();
            final userScrolledUp = useRef(false);
            final focusedMsgId = useState<String?>(null);

            // 检测手动滚动：只要不在确切底部就暂停自动滚动
            useEffect(() {
              void onScroll() {
                if (!scrollController.hasClients) return;
                userScrolledUp.value =
                    scrollController.position.pixels <
                    scrollController.position.maxScrollExtent;
              }
              scrollController.addListener(onScroll);
              return () => scrollController.removeListener(onScroll);
            }, [scrollController]);

            // 内容更新后自动滚底（仅当用户未手动上滚时）
            useEffect(() {
              if (!scrollController.hasClients) return null;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (scrollController.hasClients && !userScrolledUp.value) {
                  scrollController.jumpTo(
                    scrollController.position.maxScrollExtent,
                  );
                }
              });
              return null;
            });

            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: _readingWidth(),
                child: ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    top: custom.spacing.sm,
                    bottom: 40,
                  ),
                  itemCount: messageOrder.length + (isStreaming ? 1 : 0),
                  itemBuilder: (context, index) {
                    // 流式加载指示器（位于列表末尾）
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

                    if (parts.isNotEmpty &&
                        parts.every(
                          (p) =>
                              p.partType == 'tool_result' ||
                              p.partType == 'tool_call_frag',
                        )) {
                      return const SizedBox.shrink();
                    }

                    final dimmed = focusedMsgId.value != null &&
                        index > messageOrder.indexOf(focusedMsgId.value!);

                    return ChatMessageItem(
                      key: ValueKey(msgId),
                      sessionId: sessionId,
                      msgId: msgId,
                      role: role,
                      parts: parts,
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

  /// 从 messageOrder 尾部向前扫描，找到最后一个有 expandable part 的消息索引。
  /// 与 ChatMessageItem 的可见性逻辑保持一致。
  /// 计算每条消息是否是轮次中的第一条 assistant。
  /// assistant 消息的前一个可见用户消息视为一个轮次，
  /// 该轮次中的第一条 assistant 消息显示模型名。
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
      // 与 ChatMessageItem 的过滤逻辑一致
      if (parts.every((p) =>
          p.partType == 'tool_result' || p.partType == 'tool_call_frag')) {
        continue;
      }
      // 属于 assistant 角色且有 expandable part
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



/// 读取宽度 — 主屏物理宽度的一半
/// 等价于原 readingWidthProvider 的计算逻辑
double _readingWidth() {
  final display = PlatformDispatcher.instance.displays.first;
  return display.size.width / display.devicePixelRatio / 2;
}
