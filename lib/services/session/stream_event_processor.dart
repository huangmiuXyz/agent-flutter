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
      if (findPartContent(s, event.partId) != null) {
        s.updatePartContent(event.partId, content);
      } else {
        s.ensureMessage(event.msgId);
        s.addPart(
          event.msgId,
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
    } else if (event is EngineEvent_ToolPermissionRequest) {
      // 工具权限确认请求：把 pending 状态挂到对应卡片（part_id 为空时
      // 由 EngineClient 走弹窗回退，不在此处理）
      if (event.partId.isNotEmpty) {
        s.pendingPermissions[event.partId] = PendingToolPermission(
          callId: event.callId,
          toolName: event.toolName,
          arguments: event.arguments,
        );
      }
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
        s.ensureMessage(event.msgId);
        s.addPart(
          event.msgId,
          api.PartInfo(
            id: event.partId,
            msgId: event.msgId,
            seq: s.partCountOf(event.msgId),
            partType: PartTypes.webSearch,
            content: content,
          ),
        );
      }
    } else if (event is EngineEvent_ToolOutputDelta) {
      // 工具执行中的流式输出（shell_command 等）：按 (part_id, stream)
      // 分桶去重后追加到缓冲，渲染端（只读终端）增量写入。
      // 注意不能用全局 total_len 去重：stdout/stderr 各自累计，跨流
      // 比较会把后到的短流事件误判为重复。
      final key = '${event.partId}|${event.stream}';
      final known = s.toolOutputLens[key] ?? BigInt.zero;
      if (event.totalLen <= known) return;
      s.toolOutputLens[key] = event.totalLen;
      s.toolOutputBuffers[event.partId] =
          (s.toolOutputBuffers[event.partId] ?? '') + event.chunk;
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
    // 按 part_id 走索引定位（O(1)），避免每次 chunk 全表扫描
    final existing = s.partById(partId);
    if (existing != null) {
      s.updatePart(partId, content: existing.content + text);
      return;
    }
    // 找不到 part（工具调用后 Rust 发了新的 stream，partId 是新的）
    // 创建新消息，优先使用 Rust 侧传过来的 msgId
    // 注意：同 msgId 的消息可能已存在（如 reasoning part 先行创建），此处追加而非覆盖
    final newMsgId = msgId ?? '${partId}_msg';
    if (!s.partsByMsg.containsKey(newMsgId)) {
      s.ensureMessage(newMsgId);
      s.messageRoles[newMsgId] = 'assistant';
    }
    s.addPart(
      newMsgId,
      api.PartInfo(
        id: partId,
        msgId: newMsgId,
        seq: s.partCountOf(newMsgId),
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
    s.ensureMessage(msgId);

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
      s.addPart(
        msgId,
        api.PartInfo(
          id: partId,
          msgId: msgId,
          seq: s.partCountOf(msgId),
          partType: PartTypes.toolCall,
          content: content,
        ),
      );
    }

    s.messageRoles[msgId] = 'assistant';
    // 工具结果已到达：无论执行还是被拒绝，确认按钮都不再需要
    s.pendingPermissions.remove(partId);
  }

  /// 在 partsByMsg 中查找 partId 对应的 content，找不到返回 null
  static String? findPartContent(SessionState s, String partId) {
    return s.partById(partId)?.content;
  }
}
