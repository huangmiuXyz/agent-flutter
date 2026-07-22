import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/services/session_manager.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/divider/app_divider.dart';
import 'package:agent/features/chat/chat_input.dart';
import 'package:agent/features/chat/widgets/chat_message_item.dart';

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

        final toolCallResults = _buildToolCallResults(partsByMsg);

        if (messageOrder.isEmpty) return const SizedBox.shrink();

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: _readingWidth(),
            child: ListView.builder(
              padding: EdgeInsets.only(bottom: custom.spacing.sm),
              itemCount: messageOrder.length,
              itemBuilder: (context, index) {
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
      },
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
