/// SessionManager — 多会话并发管理器（信号版）
///
/// 职责：会话生命周期编排、响应式信号暴露。
/// 数据模型见 [SessionState]，流事件处理见 [StreamEventProcessor]。
library;

import 'dart:async';

import 'package:signals_flutter/signals_flutter.dart';
import 'package:agent/rust_bridge/api.dart' as api;

import '../llm/llm_service.dart';
import 'session_state.dart';
import 'stream_event_processor.dart';

// ─── SessionManager ───

/// 会话管理器 — 纯信号驱动
///
/// 所有可观察状态都是 [signal]，UI 层通过 [SignalBuilder] 自动追踪依赖。
class SessionManager {
  static final instance = SessionManager._();
  SessionManager._();

  // ── 响应式状态 ──

  /// 所有会话的状态树
  final sessions = signal(<String, SessionState>{});

  /// 当前选中的会话 ID
  final selectedId = signal<String?>(null);

  /// 会话列表
  final sessionList = signal(<api.SessionInfo>[]);
  final sessionListLoading = signal(true);

  /// 加载会话列表
  Future<void> loadSessions({
    required LlmService service,
    required String dbPath,
  }) async {
    sessionListLoading.value = true;
    try {
      sessionList.value = await service.listSessions(dbPath: dbPath);
    } finally {
      sessionListLoading.value = false;
    }
  }

  void addSession(api.SessionInfo session) {
    sessionList.value = [session, ...sessionList.value];
  }

  void removeSession(String id) {
    sessionList.value = sessionList.value.where((s) => s.id != id).toList();
  }

  void renameSession(String id, String newName) {
    sessionList.value = [
      for (final s in sessionList.value)
        if (s.id == id)
          api.SessionInfo(
            id: s.id,
            name: newName,
            createdAt: s.createdAt,
            updatedAt: s.updatedAt,
          )
        else
          s,
    ];
  }

  /// 当前正在流式输出的会话 ID 集合
  final streamingSessionIds = signal(<String>{});

  /// 快速访问当前会话的状态
  SessionState? stateFor(String? sessionId) =>
      sessionId != null ? sessions.value[sessionId] : null;

  // ── 内部 ──

  /// 全量变更（新增/删除消息 / 流完成）
  void _emit() {
    sessions.value = Map.from(sessions.value);
  }

  // ── 操作 ──

  /// 创建新会话并设为当前会话
  Future<String> createSession({
    required LlmService service,
    required String dbPath,
  }) async {
    final now = DateTime.now();
    final name =
        '新对话 ${now.month}/${now.day} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final session = await service.createSession(dbPath: dbPath, name: name);
    addSession(session);
    selectedId.value = session.id;
    return session.id;
  }

  Future<void> switchTo(
    String sessionId, {
    required LlmService service,
    required String dbPath,
  }) async {
    if (!sessions.value.containsKey(sessionId)) {
      sessions.value = {...sessions.value, sessionId: SessionState(sessionId)};
    }

    // ── 1. 订阅 + buffer ──
    final buffer = <api.StreamEvent>[];
    StreamSubscription<api.StreamEvent>? bufferSub;
    try {
      bufferSub = service
          .subscribeSession(dbPath: dbPath, sessionId: sessionId)
          .listen((e) => buffer.add(e), onError: (_) {});
    } catch (_) {}

    // ── 2. 读 DB ──
    try {
      final messages = await service.listMessagesBySession(
        dbPath: dbPath,
        sessionId: sessionId,
      );
      sessions.value[sessionId]!.loadFromMessages(messages);
    } catch (_) {}

    try {
      final parts = await service.listPartsBySession(
        dbPath: dbPath,
        sessionId: sessionId,
      );
      sessions.value[sessionId]!.loadFromParts(parts);
      _emit();
    } catch (_) {}

    // ── 3. 回放 buffer（total_len 去重） ──
    bufferSub?.cancel();
    for (final event in buffer) {
      StreamEventProcessor.applyEvent(sessions.value, sessionId, event);
    }

    // ── 4. gap 检测 ──
    for (final event in buffer) {
      String partId;
      BigInt totalLen;
      if (event is api.StreamEvent_Text) {
        partId = event.partId;
        totalLen = event.totalLen;
      } else if (event is api.StreamEvent_ToolCallFragment) {
        partId = event.partId;
        totalLen = event.totalLen;
      } else {
        continue;
      }
      if (partId.isEmpty || totalLen == BigInt.zero) continue;

      final s = sessions.value[sessionId]!;
      bool hasFullContent = false;
      for (final parts in s.partsByMsg.values) {
        for (final part in parts) {
          if (part.id == partId) {
            hasFullContent = part.content.length >= totalLen.toInt();
            break;
          }
        }
        if (hasFullContent) break;
      }
      if (!hasFullContent) {
        try {
          final fullContent = await service.readPart(
            dbPath: dbPath,
            partId: partId,
          );
          s.updatePartContent(partId, fullContent);
        } catch (_) {}
      }
    }

    _emit();
  }

  Future<void> sendMessage({
    required String sessionId,
    required String provider,
    required String model,
    required String prompt,
    required LlmService service,
    required String dbPath,
    required String configPath,
  }) async {
    final s = _ensureState(sessionId);

    // ── 用户消息直接显示 ──
    final userMsgId =
        '${sessionId}_user_${DateTime.now().millisecondsSinceEpoch}';
    s.messageOrder.add(userMsgId);
    s.partsByMsg[userMsgId] = [
      api.PartInfo(
        id: '${userMsgId}_part',
        msgId: userMsgId,
        seq: 0,
        partType: 'text',
        content: prompt,
      ),
    ];
    s.messageRoles[userMsgId] = 'user';

    _emit();

    streamingSessionIds.value = {...streamingSessionIds.value, sessionId};
    _emit();

    try {
      final stream = service.chatStream(
        configPath: configPath,
        provider: provider,
        model: model,
        prompt: prompt,
        dbPath: dbPath,
        sessionId: sessionId,
      );

      await for (final event in stream) {
        // 错误事件：追加到助理消息
        if (event is api.StreamEvent_Error) {
          StreamEventProcessor.appendPartContent(
            s,
            'err_${DateTime.now().millisecondsSinceEpoch}',
            '[错误] ${event.field0}',
          );
        }
        StreamEventProcessor.applyEvent(sessions.value, sessionId, event);

        // 流式创建的 assistant 消息，记录模型名
        String? eMsgId;
        if (event is api.StreamEvent_Text) {
          eMsgId = event.msgId;
        } else if (event is api.StreamEvent_ReasoningChunk) {
          eMsgId = event.msgId;
        }
        if (eMsgId != null && eMsgId.isNotEmpty &&
            !s.messageModels.containsKey(eMsgId)) {
          final label = provider.isNotEmpty
              ? '$provider / $model'
              : model;
          s.messageModels[eMsgId] = label;
        }

        _emit();
      }
    } finally {
      streamingSessionIds.value = {
        for (final id in streamingSessionIds.value)
          if (id != sessionId) id
      };
      _emit();
    }
  }

  /// 重试（编辑）用户消息
  ///
  /// 更新指定用户消息的文本内容，通过 Rust 后端重试 API 重新请求 LLM。
  Future<void> retryMessage({
    required String sessionId,
    required String msgId,
    required String newPrompt,
    required String provider,
    required String model,
    required LlmService service,
    required String dbPath,
    required String configPath,
  }) async {
    final s = _ensureState(sessionId);

    // 1. 更新本地用户消息的文本内容
    final parts = s.partsByMsg[msgId];
    if (parts != null) {
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].partType == 'text') {
          parts[i] = api.PartInfo(
            id: parts[i].id,
            msgId: parts[i].msgId,
            seq: parts[i].seq,
            partType: parts[i].partType,
            content: newPrompt,
          );
        }
      }
    }

    _emit();

    // 2. 通过 Rust 后端重试（替换 DB 中的消息内容 + 删除后续消息 + 重新请求 LLM）
    streamingSessionIds.value = {...streamingSessionIds.value, sessionId};
    _emit();

    try {
      final stream = service.chatRetry(
        configPath: configPath,
        provider: provider,
        model: model,
        msgId: msgId,
        chatText: newPrompt,
        sessionId: sessionId,
        dbPath: dbPath,
      );

      await for (final event in stream) {
        if (event is api.StreamEvent_Error) {
          StreamEventProcessor.appendPartContent(
            s,
            'err_${DateTime.now().millisecondsSinceEpoch}',
            '[错误] ${event.field0}',
          );
        }
        StreamEventProcessor.applyEvent(sessions.value, sessionId, event);

        String? eMsgId;
        if (event is api.StreamEvent_Text) {
          eMsgId = event.msgId;
        } else if (event is api.StreamEvent_ReasoningChunk) {
          eMsgId = event.msgId;
        }
        if (eMsgId != null && eMsgId.isNotEmpty &&
            !s.messageModels.containsKey(eMsgId)) {
          final label = provider.isNotEmpty
              ? '$provider / $model'
              : model;
          s.messageModels[eMsgId] = label;
        }

        _emit();
      }
    } finally {
      streamingSessionIds.value = {
        for (final id in streamingSessionIds.value)
          if (id != sessionId) id
      };
      _emit();
    }
  }

  SessionState _ensureState(String sessionId) {
    if (!sessions.value.containsKey(sessionId)) {
      sessions.value = {...sessions.value, sessionId: SessionState(sessionId)};
    }
    return sessions.value[sessionId]!;
  }

  void dispose() {}
}
