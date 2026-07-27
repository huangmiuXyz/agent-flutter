/// EngineClient — 统一引擎事件流的 Flutter 端入口
///
/// Rust 后端通过单一 `ENGINE_SINK` 推送所有事件（chat 文本、工具调用、
/// MCP 状态、前端工具调用等），本类负责：
/// - 启动时调用 [`api.connectEngine`] 建立全局 stream 订阅
/// - 按 `session_id` 把事件路由到各会话的 broadcast 流，供 [SessionStore] 订阅
/// - 把 `FrontendToolCall` 事件分发给已注册的前端工具 handler
/// - handler 执行完毕后通过 [`api.submitFrontendToolResult`] 把结果回传给 Rust
library;

import 'dart:async';

import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/rust_bridge/events.dart';

/// 前端工具 handler 函数签名。
///
/// 接收 [EngineEvent_FrontendToolCall] 事件，返回工具执行结果字符串。
/// 抛出的异常会被捕获并作为错误结果回传给 Rust。
typedef FrontendToolHandler = Future<String> Function(
  EngineEvent_FrontendToolCall event,
);

/// 引擎事件流客户端 — 全局单例
class EngineClient {
  static final instance = EngineClient._();
  EngineClient._();

  // ── 连接状态 ──
  StreamSubscription<EngineEvent>? _rootSub;
  bool _connected = false;
  bool _connecting = false;

  /// 每个 session_id 对应的 broadcast controller。
  final Map<String, StreamController<EngineEvent>> _sessionControllers = {};

  /// 工具名 → handler
  final Map<String, FrontendToolHandler> _toolHandlers = {};

  /// 已连接到 Rust 引擎事件流
  bool get isConnected => _connected;

  /// 连接到 Rust 引擎事件流。
  ///
  /// Flutter 启动时调用一次即可。重复调用会被忽略（除非先 [disconnect]）。
  Future<void> connect() async {
    if (_connected || _connecting) return;
    _connecting = true;
    try {
      final stream = api.connectEngine();
      _rootSub = stream.listen(
        _onEvent,
        onError: (Object error, StackTrace stack) {
          // FRB sink 出错后通常会自动 onDone，这里只重置连接状态
          _connected = false;
        },
        onDone: () {
          _connected = false;
        },
        cancelOnError: false,
      );
      _connected = true;
    } finally {
      _connecting = false;
    }
  }

  /// 断开连接并清理所有会话订阅。通常仅在测试或应用退出时调用。
  Future<void> disconnect() async {
    await _rootSub?.cancel();
    _rootSub = null;
    _connected = false;
    for (final c in _sessionControllers.values) {
      await c.close();
    }
    _sessionControllers.clear();
  }

  // ── 会话事件路由 ───────────────────────────────────

  /// 订阅指定会话的事件流。
  ///
  /// 返回的 broadcast stream 会收到该 session 的所有 `EngineEvent`：
  /// Chunk / ReasoningChunk / ToolCallFragment / ToolCall / FrontendToolCall
  /// / Done / Error。
  Stream<EngineEvent> subscribeSession(String sessionId) {
    return _controllerFor(sessionId).stream;
  }

  /// 关闭指定会话的事件流（保留 handler 注册）。
  void unsubscribeSession(String sessionId) {
    final c = _sessionControllers.remove(sessionId);
    if (c != null) {
      // 不等待，避免阻塞 UI
      c.close();
    }
  }

  StreamController<EngineEvent> _controllerFor(String sessionId) {
    return _sessionControllers.putIfAbsent(
      sessionId,
      () => StreamController<EngineEvent>.broadcast(),
    );
  }

  // ── 前端工具 handler 注册 ─────────────────────────

  /// 注册前端工具 handler。
  ///
  /// 当 Rust 推送 `FrontendToolCall` 事件且 `tool_name` 匹配时，调用此 handler。
  /// handler 返回的字符串会通过 [`api.submitFrontendToolResult`] 回传给 Rust。
  /// 重复注册同名工具会覆盖旧 handler。
  void registerToolHandler(String name, FrontendToolHandler handler) {
    _toolHandlers[name] = handler;
  }

  /// 注销前端工具 handler。
  void unregisterToolHandler(String name) {
    _toolHandlers.remove(name);
  }

  // ── 事件分发 ───────────────────────────────────

  void _onEvent(EngineEvent event) {
    final sid = _extractSessionId(event);
    if (sid != null && sid.isNotEmpty) {
      final c = _sessionControllers[sid];
      if (c != null && !c.isClosed) {
        c.add(event);
      }
    }

    if (event is EngineEvent_FrontendToolCall) {
      // 不 await，避免阻塞事件循环；handler 内部异步执行
      _dispatchToolCall(event);
    }
  }

  String? _extractSessionId(EngineEvent event) {
    if (event is EngineEvent_Chunk) return event.sessionId;
    if (event is EngineEvent_Done) return event.sessionId;
    if (event is EngineEvent_ToolCallFragment) return event.sessionId;
    if (event is EngineEvent_ToolCall) return event.sessionId;
    if (event is EngineEvent_ReasoningChunk) return event.sessionId;
    if (event is EngineEvent_Error) return event.sessionId;
    if (event is EngineEvent_FrontendToolCall) return event.sessionId;
    return null;
  }

  Future<void> _dispatchToolCall(EngineEvent_FrontendToolCall event) async {
    final handler = _toolHandlers[event.toolName];
    if (handler == null) {
      await api.submitFrontendToolResult(
        callId: event.callId,
        result: 'Error: no handler registered for tool "${event.toolName}"',
      );
      return;
    }

    try {
      final result = await handler(event);
      await api.submitFrontendToolResult(
        callId: event.callId,
        result: result,
      );
    } catch (e, st) {
      await api.submitFrontendToolResult(
        callId: event.callId,
        result: 'Error: $e\n$st',
      );
    }
  }
}
