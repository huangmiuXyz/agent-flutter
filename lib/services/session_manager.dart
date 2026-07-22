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
  int _streamingCount = 0;

  /// 是否有正在进行的流
  bool get isStreaming => _streamingCount > 0;

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

  void markStreaming(bool v) {
    if (v) {
      _streamingCount++;
    } else {
      _streamingCount = (_streamingCount - 1).clamp(0, _streamingCount);
    }
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
  final allStates = signal(<String, SessionState>{});

  /// 当前选中的会话 ID
  final selectedId = signal<String?>(null);

  /// 快速访问当前会话的状态
  SessionState? stateFor(String? sessionId) =>
      sessionId != null ? allStates.value[sessionId] : null;

  // ── 内部 ──
  StreamSubscription<api.StreamEvent>? _activeSubscription;

  /// 全量变更（新增/删除消息 / 流完成）
  void _emit() {
    allStates.value = Map.from(allStates.value);
  }

  // ── 操作 ──

  /// 切换到指定会话
  Future<void> switchTo(
    String sessionId, {
    required LlmService service,
    required String dbPath,
  }) async {
    _activeSubscription?.cancel();

    if (!allStates.value.containsKey(sessionId)) {
      allStates.value = {
        ...allStates.value,
        sessionId: SessionState(sessionId),
      };
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
      allStates.value[sessionId]!.loadFromMessages(messages);
    } catch (_) {}

    try {
      final parts = await service.listPartsBySession(
        dbPath: dbPath,
        sessionId: sessionId,
      );
      allStates.value[sessionId]!.loadFromParts(parts);
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

      final s = allStates.value[sessionId]!;
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

    // ── 5. 实时模式 ──
    if (allStates.value[sessionId]!.isStreaming) {
      try {
        _activeSubscription = service
            .subscribeSession(dbPath: dbPath, sessionId: sessionId)
            .listen((event) {
              _applyEvent(sessionId, event);
              _emit();
            }, onError: (_) {});
      } catch (_) {}
    }

    _emit();
  }

  void switchAway() {
    _activeSubscription?.cancel();
    _activeSubscription = null;
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

    // ── 预留助理消息位置（partId 用 Rust 流里的，首次 Text 事件再填入） ──
    String? assistantPartId;
    final assistantMsgId =
        '${sessionId}_asst_${DateTime.now().millisecondsSinceEpoch}';
    s.messageOrder.add(assistantMsgId);
    s.messageRoles[assistantMsgId] = 'assistant';

    s.markStreaming(true);
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
        _applyEvent(sessionId, event);

        // 首次 Text 事件：用 Rust 的 partId 填入助理消息
        if (event is api.StreamEvent_Text && assistantPartId == null) {
          assistantPartId = event.partId;
          s.partsByMsg[assistantMsgId] = [
            api.PartInfo(
              id: assistantPartId,
              msgId: assistantMsgId,
              seq: 0,
              partType: 'text',
              content: '',
            ),
          ];
        }
        _emit();
      }
    } finally {
      s.markStreaming(false);
      _emit();
    }
  }

  SessionState _ensureState(String sessionId) {
    if (!allStates.value.containsKey(sessionId)) {
      allStates.value = {
        ...allStates.value,
        sessionId: SessionState(sessionId),
      };
    }
    return allStates.value[sessionId]!;
  }

  void _applyEvent(String sid, api.StreamEvent event) {
    final s = allStates.value[sid];
    if (s == null) return;

    if (event is api.StreamEvent_Text) {
      if (s.isTextRedundant(event.partId, event.totalLen)) return;
      s.trackTextLength(event.partId, event.totalLen);
      s.markStreaming(true);

      if (event.content.isNotEmpty && event.partId.isNotEmpty) {
        // 找到 partId 对应的 part，追加文本内容
        _appendPartContent(s, event.partId, event.content);
      }
    } else if (event is api.StreamEvent_ToolCallFragment) {
      if (s.isTextRedundant(event.partId, event.totalLen)) return;
      s.trackTextLength(event.partId, event.totalLen);
      s.markStreaming(true);

      // 累积 tool_call_frag 内容
      final existing = _findPartContent(s, event.partId);
      final prev = existing ?? '';
      final merged = _mergeToolCallFrag(prev, event);
      _appendPartContent(s, event.partId, merged);

      // 如果 part 还不存在，动态添加到 partsByMsg
      if (existing == null) {
        _addToolCallFragPart(s, event);
      }
    } else if (event is api.StreamEvent_ToolCall) {
      s.markStreaming(true);
    } else if (event is api.StreamEvent_Done) {
      s.markStreaming(false);
    } else if (event is api.StreamEvent_Error) {
      s.markStreaming(false);
    }
  }

  /// 在 partsByMsg 中找到 partId 对应的 part，追加文本
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

  void dispose() {
    _activeSubscription?.cancel();
  }
}
