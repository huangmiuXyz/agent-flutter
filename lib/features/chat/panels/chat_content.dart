import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/services/llm_providers.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/utils/layout_utils.dart';
import 'package:agent/widgets/divider/app_divider.dart';
import 'package:agent/features/chat/chat_input.dart';
import 'package:agent/features/chat/widgets/chat_message_item.dart';

/// 聊天内容区 — 消息列表（虚拟滚动）+ 输入框
class ChatContent extends HookConsumerWidget {
  const ChatContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedSessionProvider);

    return Column(
      children: [
        Expanded(
          child: selectedId != null
              ? _MessageList(sessionId: selectedId)
              : const SizedBox.shrink(),
        ),
        const AppDivider(extent: 1, thickness: 1),
        const ChatInput(),
      ],
    );
  }
}

/// 消息列表 — 只监听结构变更，流式更新穿透到单个消息组件
class _MessageList extends HookConsumerWidget {
  final String sessionId;

  const _MessageList({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = CustomTheme.of(context);
    final manager = ref.watch(sessionManagerProvider);

    // 只监听结构变更（useListenable + ValueNotifier），不监听流式更新
    useListenable(manager.structureNotifier);

    final sessionState = manager.state[sessionId];
    if (sessionState == null) return const SizedBox.shrink();

    final messageOrder = sessionState.messageOrder;
    final partsByMsg = sessionState.partsByMsg;
    final messageRoles = sessionState.messageRoles;

    final toolCallResults = _buildToolCallResults(partsByMsg);

    if (messageOrder.isEmpty) return const SizedBox.shrink();

    final readingWidth = ref.watch(readingWidthProvider);

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: readingWidth,
        child: ListView.builder(
          padding: EdgeInsets.only(bottom: custom.spacing.sm),
          itemCount: messageOrder.length,
          itemBuilder: (context, index) {
            final msgId = messageOrder[index];
            final parts = partsByMsg[msgId] ?? [];
            final role = messageRoles[msgId] ?? '';

            // 跳过纯 tool_result/tool_call_frag 的消息（内容已合并到 tool_call 中）
            if (parts.isNotEmpty &&
                parts.every((p) => p.partType == 'tool_result' || p.partType == 'tool_call_frag')) {
              return const SizedBox.shrink();
            }

            return ChatMessageItem(
              key: ValueKey(msgId),
              sessionId: sessionId,
              msgId: msgId,
              role: role,
              parts: parts,
              toolCallResults: toolCallResults,
            );
          },
        ),
      ),
    );
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
              // 只提取实际结果 content，不存 tool_call_id / name 等元数据
              final resultContent = json['content'] as String?;
              results[toolCallId] = (resultContent != null && resultContent.isNotEmpty)
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
