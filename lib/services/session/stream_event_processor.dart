/// 流事件处理 — 将 [EngineEvent] 应用到 [SessionState]
///
/// 纯逻辑层，无状态、无副作用依赖（只修改传入的 [SessionState]）。
library;

import 'dart:convert';

import 'package:agent/rust_bridge/api/types.dart' as api;
import 'package:agent/rust_bridge/events.dart';

import 'part_types.dart';
import 'session_state.dart';

class StreamEventProcessor {
  /// 通过 sessions map 查找会话状态并应用事件
  static void applyEvent(
    Map<String, SessionState> sessions,
    String sid,
    EngineEvent event,
  ) {
    final s = sessions[sid];
    if (s == null) return;
    applyToState(s, event);
  }

  /// 直接将事件应用到指定的 [SessionState]
  static void applyToState(SessionState s, EngineEvent event) {
    if (event is EngineEvent_Chunk) {
      if (s.isTextRedundant(event.partId, event.totalLen)) return;
      s.trackTextLength(event.partId, event.totalLen);

      if (event.content.isNotEmpty && event.partId.isNotEmpty) {
        appendPartContent(
          s,
          event.partId,
          event.content,
          msgId: event.msgId.isNotEmpty ? event.msgId : null,
        );
      }
    } else if (event is EngineEvent_ToolCallFragment) {
      // 工具调用片段：后端每次发“当前完整参数”，直接覆盖（幂等，无需去重）
      final content = jsonEncode({
        'id': event.id,
        'call_type': 'function',
        'function': {'name': event.name, 'arguments': event.arguments},
      });
      final existing = findPartContent(s, event.partId);
      if (existing != null) {
        s.updatePartContent(event.partId, content);
      } else {
        _ensureMessageExists(s, event.msgId);
        s.partsByMsg[event.msgId]!.add(
          api.PartInfo(
            id: event.partId,
            msgId: event.msgId,
            seq: event.index,
            partType: PartTypes.toolCallFrag,
            content: content,
          ),
        );
      }
    } else if (event is EngineEvent_ToolCall) {
      // 工具调用完成：与流式片段同一 part_id，原地覆盖为带结果的完整卡片
      handleToolCall(
        s,
        event.msgId,
        event.partId,
        event.toolName,
        event.arguments,
        event.result,
      );
    } else if (event is EngineEvent_ReasoningChunk) {
      if (s.isReasoningRedundant(event.partId, event.totalLen)) return;
      s.trackReasoningLength(event.partId, event.totalLen);

      if (event.content.isNotEmpty && event.partId.isNotEmpty) {
        appendReasoningContent(
          s,
          event.partId,
          event.content,
          msgId: event.msgId.isNotEmpty ? event.msgId : null,
        );
      }
    } else if (event is EngineEvent_WebSearchCall) {
      // 服务端联网搜索：同一 part 按状态递进更新（in_progress → completed）。
      // 事件携带完整内容 JSON（含 action），与 DB 落库一致，
      // 流式展示不丢搜索词/地址；旧事件无 content 时兜底构造。
      final content = event.content.isNotEmpty
          ? event.content
          : jsonEncode({
              'status': event.status,
              'search_query': event.searchQuery,
            });
      final existing = findPartContent(s, event.partId);
      if (existing == content) return; // 同一状态去重
      if (existing != null) {
        s.updatePartContent(event.partId, content);
      } else {
        _ensureMessageExists(s, event.msgId);
        s.partsByMsg[event.msgId]!.add(
          api.PartInfo(
            id: event.partId,
            msgId: event.msgId,
            seq: s.partsByMsg[event.msgId]!.length,
            partType: PartTypes.webSearch,
            content: content,
          ),
        );
      }
    }
    // FrontendToolCall / Done / Error 不在此处理 — 由上层（SessionStore / EngineClient）处理
  }

  /// 在 partsByMsg 中找到 partId 对应的 reasoning part，追加内容。
  /// 找不到时自动创建新消息。
  static void appendReasoningContent(
    SessionState s,
    String partId,
    String text, {
    String? msgId,
  }) {
    _appendContent(s, partId, text, PartTypes.reasoning, msgId: msgId);
  }

  /// 在 partsByMsg 中找到 partId 对应的 part，追加文本。
  /// 找不到时自动创建新消息。
  static void appendPartContent(
    SessionState s,
    String partId,
    String text, {
    String? msgId,
  }) {
    _appendContent(s, partId, text, PartTypes.text, msgId: msgId);
  }

  /// [appendPartContent] / [appendReasoningContent] 的公共实现。
  static void _appendContent(
    SessionState s,
    String partId,
    String text,
    String partType, {
    String? msgId,
  }) {
    for (final parts in s.partsByMsg.values) {
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].id == partId) {
          parts[i] = parts[i].copyWith(content: parts[i].content + text);
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
        partType: partType,
        content: text,
      ),
    );
  }

  /// 处理工具调用完成事件：原地覆盖同一 part_id 的卡片（含内嵌结果）。
  static void handleToolCall(
    SessionState s,
    String msgId,
    String partId,
    String name,
    String arguments,
    String result,
  ) {
    if (msgId.isEmpty || partId.isEmpty) return;
    _ensureMessageExists(s, msgId);

    final content = jsonEncode({
      'id': partId,
      'call_type': 'function',
      'function': {'name': name, 'arguments': arguments},
      'tool_result': result,
    });

    final existing = findPartContent(s, partId);
    if (existing != null) {
      s.updatePartContent(partId, content);
      // 类型同步为完成态（tool_call_frag → tool_call）
      s.updatePartType(partId, PartTypes.toolCall);
    } else {
      // 极端情况：没收到片段事件（如重连后），直接新建完成态卡片
      s.partsByMsg[msgId]!.add(
        api.PartInfo(
          id: partId,
          msgId: msgId,
          seq: s.partsByMsg[msgId]!.length,
          partType: PartTypes.toolCall,
          content: content,
        ),
      );
    }

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
}
