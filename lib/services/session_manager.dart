/// SessionManager — 多会话并发管理器
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent/rust_bridge/api.dart' as api;
import 'llm_providers.dart';

// ─── SessionState ───

/// 单个会话的内存状态
class SessionState {
  final String sessionId;
  bool isStreaming = false;

  /// 按 msg_id 分组的 parts
  final Map<String, List<api.PartInfo>> partsByMsg = {};

  /// msg_id 的顺序列表
  final List<String> messageOrder = [];

  /// part_id → 已知内容长度（用于 total_len 去重）
  final Map<String, int> partLens = {};

  SessionState(this.sessionId);

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
    isStreaming = v;
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
/// 通过 [ChangeNotifier] 通知状态变更，UI 层可用 [useListenable] 监听。
class SessionManager extends ChangeNotifier {
  final Ref _ref;
  Map<String, SessionState> _state = {};
  StreamSubscription<api.StreamEvent>? _activeSubscription;

  SessionManager(this._ref);

  /// 当前所有会话状态
  Map<String, SessionState> get state => _state;

  void _emit(Map<String, SessionState> next) {
    _state = next;
    notifyListeners();
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

    service.chatStream(
      configPath: configPath,
      provider: provider,
      model: model,
      prompt: prompt,
      dbPath: dbPath,
      sessionId: sessionId,
    );
  }

  void _applyEvent(String sid, api.StreamEvent event) {
    final s = _state[sid];
    if (s == null) return;

    if (event is api.StreamEvent_Text) {
      if (s.isTextRedundant(event.partId, event.totalLen)) return;
      s.trackTextLength(event.partId, event.totalLen);
      s.markStreaming(true);
    } else if (event is api.StreamEvent_ToolCallFragment) {
      if (s.isTextRedundant(event.partId, event.totalLen)) return;
      s.trackTextLength(event.partId, event.totalLen);
      s.markStreaming(true);
    } else if (event is api.StreamEvent_ToolCall) {
      s.markStreaming(true);
    } else if (event is api.StreamEvent_Done) {
      s.markStreaming(false);
    }
  }

  @override
  void dispose() {
    _activeSubscription?.cancel();
    super.dispose();
  }
}
