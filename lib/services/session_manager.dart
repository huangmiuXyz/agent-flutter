/// SessionManager — 多会话并发管理器
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent/rust_bridge/api.dart' as api;
import 'llm_providers.dart';

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

  /// part_id → 流式累积的文本内容（用于实时 UI 显示）
  final Map<String, String> streamingContent = {};

  /// 内部 StringBuffer，避免 1000次/s 的字符串拼接产生大量 GC
  final Map<String, StringBuffer> _streamingBufs = {};

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
    streamingContent.clear();

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

/// 会话管理器
///
/// 通过 [ChangeNotifier] 通知状态变更，UI 层可直接用 [useListenable] 监听。
/// 流式内容更新通过 [streamingNotifier] 单独通知，避免触发全量重建。
class SessionManager extends ChangeNotifier {
  final Ref _ref;
  Map<String, SessionState> _state = {};
  StreamSubscription<api.StreamEvent>? _activeSubscription;
  bool _disposed = false;

  /// 结构变更通知（新增/删除消息）— 触发消息列表整体重建
  final structureNotifier = ValueNotifier<int>(0);

  /// 流式内容更新通知 — 携带变化的 partId，UI 层可据此只重建对应的消息组件。
  final streamingNotifier = ValueNotifier<String?>(null);

  SessionManager(this._ref);

  /// 当前所有会话状态
  Map<String, SessionState> get state => _state;

  /// 结构变更（新增/删除消息）→ structureNotifier + ChangeNotifier
  void _emit(Map<String, SessionState> next) {
    if (_disposed) return;
    _state = next;
    structureNotifier.value++;
    notifyListeners();
  }

  /// 流式内容更新（仅 streamingContent 变化）→ streamingNotifier
  void _emitStreaming(String partId) {
    if (_disposed) return;
    streamingNotifier.value = partId;
  }

  /// 切换到指定会话
  Future<void> switchTo(String sessionId) async {
    _activeSubscription?.cancel();

    final service = _ref.read(llmServiceProvider);
    final dbPath = _ref.read(dbPathProvider);

    _state[sessionId] ??= SessionState(sessionId);
    _emit(Map.from(_state));

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
      _state[sessionId]!.loadFromMessages(messages);
    } catch (_) {}

    try {
      final parts = await service.listPartsBySession(
        dbPath: dbPath,
        sessionId: sessionId,
      );
      _state[sessionId]!.loadFromParts(parts);
      _emit(Map.from(_state));
    } catch (_) {}

    // ── 3. 回放 buffer（total_len 去重） ──
    bufferSub?.cancel();
    for (final event in buffer) {
      _applyEvent(sessionId, event);
    }

    // ── 4. gap 检测：buffer 中 Text / ToolCallFragment 的 part 不完整时从 DB 补 ──
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

      bool hasFullContent = false;
      for (final parts in _state[sessionId]!.partsByMsg.values) {
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
          _state[sessionId]!.updatePartContent(partId, fullContent);
        } catch (_) {}
      }
    }

    // ── 5. 实时模式 ──
    if (_state[sessionId]!.isStreaming) {
      try {
        _activeSubscription = service
            .subscribeSession(dbPath: dbPath, sessionId: sessionId)
            .listen((event) {
              _applyEvent(sessionId, event);
              _emit(Map.from(_state));
            }, onError: (_) {});
      } catch (_) {}
    }

    _emit(Map.from(_state));
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
  }) async {
    final service = _ref.read(llmServiceProvider);
    final dbPath = _ref.read(dbPathProvider);
    final configPath = _ref.read(configPathProvider);

    _state.putIfAbsent(sessionId, () => SessionState(sessionId));
    _state[sessionId]!.markStreaming(true);
    _emit(Map.from(_state));

    try {
      final stream = service.chatStream(
        configPath: configPath,
        provider: provider,
        model: model,
        prompt: prompt,
        dbPath: dbPath,
        sessionId: sessionId,
      );

      // ⭐ 消费返回的 Stream — 这是主要的事件来源
      await for (final event in stream) {
        _applyEvent(sessionId, event);
        if (event is api.StreamEvent_Text) {
          // 文本增量 — 只通知 streamingNotifier，不触发全量 rebuild
          _emitStreaming(event.partId);
        } else if (event is api.StreamEvent_ToolCallFragment) {
          // ToolCallFragment 同时要做两件事：
          //   1. _emitStreaming  → 该消息组件内的渐进内容更新
          //   2. _emit           → _MessageList 重建，捡起新加到 partsByMsg 的 tool_call_frag
          _emitStreaming(event.partId);
          _emit(Map.from(_state));
        } else {
          // 结构变化（ToolCall, Done, Error）走全量通知
          _emit(Map.from(_state));
        }
      }
    } finally {
      _state[sessionId]?.markStreaming(false);
      _emit(Map.from(_state));
    }
  }

  void _applyEvent(String sid, api.StreamEvent event) {
    final s = _state[sid];
    if (s == null) return;

    if (event is api.StreamEvent_Text) {
      if (s.isTextRedundant(event.partId, event.totalLen)) return;
      s.trackTextLength(event.partId, event.totalLen);
      s.markStreaming(true);

      // 累积流式文本到 streamingContent，供 UI 实时渲染
      if (event.content.isNotEmpty && event.partId.isNotEmpty) {
        final buf = s._streamingBufs.putIfAbsent(event.partId, () => StringBuffer());
        buf.write(event.content);
        s.streamingContent[event.partId] = buf.toString();
      }
    } else if (event is api.StreamEvent_ToolCallFragment) {
      if (s.isTextRedundant(event.partId, event.totalLen)) return;
      s.trackTextLength(event.partId, event.totalLen);
      s.markStreaming(true);

      // 累积 tool_call_frag 内容到 streamingContent，供 UI 渐进渲染
      final prev = s.streamingContent[event.partId] ?? '';
      final parsed = prev.isNotEmpty
          ? (jsonDecode(prev) as Map<String, dynamic>)
          : <String, dynamic>{};
      if (event.id != null) parsed['id'] = event.id;
      if (event.name != null) parsed['name'] = event.name;
      if (event.arguments != null) {
        parsed['arguments'] = (parsed['arguments'] as String? ?? '') + event.arguments!;
      }
      s.streamingContent[event.partId] = jsonEncode(parsed);

      // 动态添加 tool_call_frag 到 partsByMsg（如果尚未存在）
      bool partExists = false;
      for (final entry in s.partsByMsg.entries) {
        if (entry.value.any((p) => p.id == event.partId)) {
          partExists = true;
          break;
        }
      }
      if (!partExists) {
        // partId 格式: tcf_{msgId}_{index}
        final segs = event.partId.split('_');
        if (segs.length >= 3 && segs[0] == 'tcf') {
          final last = int.tryParse(segs.last);
          if (last != null) {
            // 重建 msgId: 去掉 'tcf_' 前缀和末尾的 index
            final msgId = segs.sublist(1, segs.length - 1).join('_');
            if (msgId.isNotEmpty) {
              s.partsByMsg.putIfAbsent(msgId, () => []).add(api.PartInfo(
                id: event.partId,
                msgId: msgId,
                seq: event.index,
                partType: 'tool_call_frag',
                content: '',
              ));
              if (!s.messageOrder.contains(msgId)) {
                s.messageOrder.add(msgId);
              }
            }
          }
        }
      }
    } else if (event is api.StreamEvent_ToolCall) {
      s.markStreaming(true);
    } else if (event is api.StreamEvent_Done) {
      s.markStreaming(false);
    } else if (event is api.StreamEvent_Error) {
      s.markStreaming(false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _activeSubscription?.cancel();
    structureNotifier.dispose();
    streamingNotifier.dispose();
    super.dispose();
  }
}
