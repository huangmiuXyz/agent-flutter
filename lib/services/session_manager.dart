/// SessionManager — 多会话并发管理器（信号版）
library;

import 'dart:async';
import 'dart:convert';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:agent/rust_bridge/api.dart' as api;
import 'llm_service.dart';

// ─── SessionState ───

/// 单个会话的内存状态
class SessionState {
  final String sessionId;

  /// 按 msg_id 分组的 parts
  final Map<String, List<api.PartInfo>> partsByMsg = {};

  /// msg_id 的顺序列表
  final List<String> messageOrder = [];

  /// part_id → 已知内容长度（用于 total_len 去重）
  final Map<String, int> partLens = {};

  /// msg_id → role（"user", "assistant", "tool" 等）
  final Map<String, String> messageRoles = {};

  SessionState(this.sessionId);

  /// 从 DB 读取的消息角色加载
  void loadFromMessages(List<api.MessageInfo> messages) {
    messageRoles.clear();
    for (final msg in messages) {
      messageRoles[msg.id] = msg.role;
    }
  }

  /// 从 DB 读取的 parts 加载状态
  void loadFromParts(List<api.PartInfo> parts) {
    partsByMsg.clear();
    messageOrder.clear();
    partLens.clear();

    for (final part in parts) {
      partsByMsg.putIfAbsent(part.msgId, () => []).add(part);
      if (!messageOrder.contains(part.msgId)) {
        messageOrder.add(part.msgId);
      }
      if (part.partType == 'text') {
        partLens[part.id] = part.content.length;
      }
    }
  }

  /// 通过 part_id + total_len 判断是否已有数据
  bool isTextRedundant(String partId, BigInt totalLen) {
    final known = partLens[partId] ?? 0;
    return totalLen.toInt() <= known;
  }

  void trackTextLength(String partId, BigInt totalLen) {
    partLens[partId] = totalLen.toInt();
  }

  /// 更新 part 的完整内容（用于 gap 修复后）
  void updatePartContent(String partId, String content) {
    for (final entry in partsByMsg.entries) {
      for (int i = 0; i < entry.value.length; i++) {
        if (entry.value[i].id == partId) {
          final old = entry.value[i];
          entry.value[i] = api.PartInfo(
            id: old.id,
            msgId: old.msgId,
            seq: old.seq,
            partType: old.partType,
            content: content,
          );
          return;
        }
      }
    }
  }
}

// ─── SessionManager ───

/// 会话管理器 — 纯信号驱动
///
/// 所有可观察状态都是 [signal]，UI 层通过 [SignalBuilder] 自动追踪依赖，
/// 不再需要 ChangeNotifier / ValueNotifier / useListenable。
class SessionManager {
  static final instance = SessionManager._();
  SessionManager._();

  // ── 响应式状态 ──

  /// 所有会话的状态
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
      _applyEvent(sessionId, event);
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

  /// 全量变更
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
          _appendPartContent(
            s,
            'err_${DateTime.now().millisecondsSinceEpoch}',
            '[错误] ${event.field0}',
          );
        }
        _applyEvent(sessionId, event);
        _emit();
      }
    } finally {
      _emit();
    }
  }

  SessionState _ensureState(String sessionId) {
    if (!sessions.value.containsKey(sessionId)) {
      sessions.value = {...sessions.value, sessionId: SessionState(sessionId)};
    }
    return sessions.value[sessionId]!;
  }

  void _applyEvent(String sid, api.StreamEvent event) {
    final s = sessions.value[sid];
    if (s == null) return;

    if (event is api.StreamEvent_Text) {
      if (s.isTextRedundant(event.partId, event.totalLen)) return;
      s.trackTextLength(event.partId, event.totalLen);

      if (event.content.isNotEmpty && event.partId.isNotEmpty) {
        _appendPartContent(s, event.partId, event.content);
      }
    } else if (event is api.StreamEvent_ToolCallFragment) {
      if (s.isTextRedundant(event.partId, event.totalLen)) return;
      s.trackTextLength(event.partId, event.totalLen);

      final existing = _findPartContent(s, event.partId);
      final prev = existing ?? '';
      final merged = _mergeToolCallFrag(prev, event);
      _appendPartContent(s, event.partId, merged);

      if (existing == null) {
        _addToolCallFragPart(s, event);
      }
    }
  }

  /// 在 partsByMsg 中找到 partId 对应的 part，追加文本
  /// 找不到时自动创建新消息
  void _appendPartContent(SessionState s, String partId, String text) {
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
    // 创建新消息
    final msgId = '${partId}_msg';
    s.messageOrder.add(msgId);
    s.partsByMsg[msgId] = [
      api.PartInfo(
        id: partId,
        msgId: msgId,
        seq: 0,
        partType: 'text',
        content: text,
      ),
    ];
    s.messageRoles[msgId] = 'assistant';
  }

  /// 在 partsByMsg 中查找 partId 对应的 content，找不到返回 null
  String? _findPartContent(SessionState s, String partId) {
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
  String _mergeToolCallFrag(
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
  void _addToolCallFragPart(
    SessionState s,
    api.StreamEvent_ToolCallFragment event,
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
                  content: '',
                ),
              );
          if (!s.messageOrder.contains(msgId)) {
            s.messageOrder.add(msgId);
          }
        }
      }
    }
  }

  void dispose() {}
}
