/// 流事件处理 — 将 [api.StreamEvent] 应用到 [SessionState]
///
/// 纯逻辑层，无状态、无副作用依赖（只修改传入的 [SessionState]）。
library;

import 'dart:convert';

import 'package:agent/rust_bridge/api.dart' as api;

import 'session_state.dart';

class StreamEventProcessor {
  /// 通过 sessions map 查找会话状态并应用事件
  static void applyEvent(
    Map<String, SessionState> sessions,
    String sid,
    api.StreamEvent event,
  ) {
    final s = sessions[sid];
    if (s == null) return;
    applyToState(s, event);
  }

  /// 直接将事件应用到指定的 [SessionState]
  static void applyToState(SessionState s, api.StreamEvent event) {
    if (event is api.StreamEvent_Text) {
      if (s.isTextRedundant(event.partId, event.totalLen)) return;
      s.trackTextLength(event.partId, event.totalLen);

      if (event.content.isNotEmpty && event.partId.isNotEmpty) {
        appendPartContent(s, event.partId, event.content,
            msgId: event.msgId.isNotEmpty ? event.msgId : null);
      }
    } else if (event is api.StreamEvent_ToolCallFragment) {
      if (s.isTextRedundant(event.partId, event.totalLen)) return;
      s.trackTextLength(event.partId, event.totalLen);

      final existing = findPartContent(s, event.partId);
      final prev = existing ?? '';
      final merged = mergeToolCallFrag(prev, event);

      if (existing != null) {
        // 已有 part，更新合并后的内容
        s.updatePartContent(event.partId, merged);
      } else {
        // 新建 tool_call_frag part，带初始合并内容
        addToolCallFragPart(s, event, merged);
      }
    } else if (event is api.StreamEvent_ToolCall) {
      handleToolCall(s, event.msgId, event.name, event.arguments, event.result);
    } else if (event is api.StreamEvent_ReasoningChunk) {
      if (s.isReasoningRedundant(event.partId, event.totalLen)) return;
      s.trackReasoningLength(event.partId, event.totalLen);

      if (event.content.isNotEmpty && event.partId.isNotEmpty) {
        appendReasoningContent(s, event.partId, event.content,
            msgId: event.msgId.isNotEmpty ? event.msgId : null);
      }
    }
  }

  /// 在 partsByMsg 中找到 partId 对应的 reasoning part，追加内容。
  /// 找不到时自动创建新消息。
  static void appendReasoningContent(SessionState s, String partId, String text,
      {String? msgId}) {
    for (final parts in s.partsByMsg.values) {
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].id == partId) {
          final old = parts[i];
          parts[i] = api.PartInfo(
            id: old.id,
            msgId: old.msgId,
            seq: old.seq,
            partType: old.partType,
            content: old.content + text,
          );
          return;
        }
      }
    }
    // 找不到 part，创建新消息（或追加到同 msgId 的已有消息）
    final newMsgId = msgId ?? '${partId}_msg';
    if (!s.partsByMsg.containsKey(newMsgId)) {
      s.messageOrder.add(newMsgId);
      s.partsByMsg[newMsgId] = [];
      s.messageRoles[newMsgId] = 'assistant';
    }
    s.partsByMsg[newMsgId]!.add(
      api.PartInfo(
        id: partId,
        msgId: newMsgId,
        seq: s.partsByMsg[newMsgId]!.length,
        partType: 'reasoning',
        content: text,
      ),
    );
  }

  /// 在 partsByMsg 中找到 partId 对应的 part，追加文本。
  /// 找不到时自动创建新消息。
  static void appendPartContent(SessionState s, String partId, String text,
      {String? msgId}) {
    for (final parts in s.partsByMsg.values) {
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].id == partId) {
          final old = parts[i];
          parts[i] = api.PartInfo(
            id: old.id,
            msgId: old.msgId,
            seq: old.seq,
            partType: old.partType,
            content: old.content + text,
          );
          return;
        }
      }
    }
    // 找不到 part（工具调用后 Rust 发了新的 stream，partId 是新的）
    // 创建新消息，优先使用 Rust 侧传过来的 msgId
    // 注意：同 msgId 的消息可能已存在（如 reasoning part 先行创建），此处追加而非覆盖
    final newMsgId = msgId ?? '${partId}_msg';
    if (!s.partsByMsg.containsKey(newMsgId)) {
      s.messageOrder.add(newMsgId);
      s.partsByMsg[newMsgId] = [];
      s.messageRoles[newMsgId] = 'assistant';
    }
    s.partsByMsg[newMsgId]!.add(
      api.PartInfo(
        id: partId,
        msgId: newMsgId,
        seq: s.partsByMsg[newMsgId]!.length,
        partType: 'text',
        content: text,
      ),
    );
  }

  /// 处理工具调用完成事件，将 tool_call part 添加到对应消息
  static void handleToolCall(
      SessionState s, String msgId, String name, String arguments, String result) {
    if (msgId.isEmpty) return;
    _ensureMessageExists(s, msgId);

    // 移除该消息下的所有 tool_call_frag，因为已收到完整的 tool_call
    s.partsByMsg[msgId]!.removeWhere((p) => p.partType == 'tool_call_frag');

    // 添加 tool_call part，内联结果以便流式渲染时可直接显示
    final toolCallJson = jsonEncode({
      'id': 'tc_$msgId',
      'function': {
        'name': name,
        'arguments': arguments,
      },
      '_result': result,
    });

    s.partsByMsg[msgId]!.add(api.PartInfo(
      id: 'tc_${msgId}_${s.partsByMsg[msgId]!.length}',
      msgId: msgId,
      seq: s.partsByMsg[msgId]!.length,
      partType: 'tool_call',
      content: toolCallJson,
    ));

    s.messageRoles[msgId] = 'assistant';
  }

  /// 确保消息存在
  static void _ensureMessageExists(SessionState s, String msgId) {
    if (!s.partsByMsg.containsKey(msgId)) {
      s.partsByMsg[msgId] = [];
      if (!s.messageOrder.contains(msgId)) {
        s.messageOrder.add(msgId);
      }
    }
  }

  /// 在 partsByMsg 中查找 partId 对应的 content，找不到返回 null
  static String? findPartContent(SessionState s, String partId) {
    for (final parts in s.partsByMsg.values) {
      for (final part in parts) {
        if (part.id == partId) {
          return part.content;
        }
      }
    }
    return null;
  }

  /// 合并新的 tool_call_frag 事件到已有内容中
  static String mergeToolCallFrag(
    String prev,
    api.StreamEvent_ToolCallFragment event,
  ) {
    final parsed = prev.isNotEmpty
        ? (jsonDecode(prev) as Map<String, dynamic>)
        : <String, dynamic>{};
    if (event.id != null) parsed['id'] = event.id;
    if (event.name != null) parsed['name'] = event.name;
    if (event.arguments != null) {
      parsed['arguments'] =
          (parsed['arguments'] as String? ?? '') + event.arguments!;
    }
    return jsonEncode(parsed);
  }

  /// 动态添加 tool_call_frag 到 partsByMsg
  static void addToolCallFragPart(
    SessionState s,
    api.StreamEvent_ToolCallFragment event,
    String initialContent,
  ) {
    final segs = event.partId.split('_');
    if (segs.length >= 3 && segs[0] == 'tcf') {
      final last = int.tryParse(segs.last);
      if (last != null) {
        final msgId = segs.sublist(1, segs.length - 1).join('_');
        if (msgId.isNotEmpty) {
          s.partsByMsg
              .putIfAbsent(msgId, () => [])
              .add(
                api.PartInfo(
                  id: event.partId,
                  msgId: msgId,
                  seq: event.index,
                  partType: 'tool_call_frag',
                  content: initialContent,
                ),
              );
          if (!s.messageOrder.contains(msgId)) {
            s.messageOrder.add(msgId);
          }
          s.messageRoles[msgId] = 'assistant';
        }
      }
    }
  }
}
