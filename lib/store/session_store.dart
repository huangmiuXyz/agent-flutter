/// SessionStore — 多会话并发管理器（信号版）
///
/// 职责：会话生命周期编排、响应式信号暴露。
/// 数据模型见 [SessionState]，流事件处理见 [StreamEventProcessor]。
///
/// 在统一 `ENGINE_SINK` 模型下，事件订阅通过 [EngineClient] 完成：
/// - 启动时调用 `EngineClient.connect()` 建立全局 stream
/// - 切换会话或发送消息时，订阅对应 session 的事件流
/// - 事件通过 `StreamEventProcessor` 应用到 [SessionState]
library;

import 'dart:async';

import 'package:signals_flutter/signals_flutter.dart';
import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/rust_bridge/events.dart';

import 'package:agent/services/engine/engine_client.dart';
import 'package:agent/services/llm/llm_service.dart';
import 'package:agent/features/agents/store/agent_store.dart';
import 'package:agent/store/config_store.dart';
import 'package:agent/store/message_queue_store.dart';
import 'package:agent/services/session/session_state.dart';
import 'package:agent/services/session/stream_event_processor.dart';
import 'package:agent/services/session/part_types.dart';

// ─── SessionStore ───

/// 会话管理器 — 纯信号驱动
///
/// 所有可观察状态都是 [signal]，UI 层通过 [SignalBuilder] 自动追踪依赖。
class SessionStore {
  static final instance = SessionStore._();
  SessionStore._();

  // ── 响应式状态 ──

  /// 所有会话的状态树
  final sessions = signal(<String, SessionState>{});

  /// 当前选中的会话 ID
  final selectedId = signal<String?>(null);

  /// 当前内容区显示的会话 ID（仅在数据就绪后切换，避免空白过渡）
  final displayedSessionId = signal<String?>(null);

  /// 会话列表
  final sessionList = signal(<api.SessionInfo>[]);
  final sessionListLoading = signal(true);

  /// 当前正在流式输出的会话 ID 集合
  final streamingSessionIds = signal(<String>{});

  // ── 内部 ──

  /// 每个 session 的事件订阅句柄（用于切换会话或销毁时取消）
  final Map<String, StreamSubscription<EngineEvent>> _sessionSubs = {};

  /// 每个 session 最近一次 sendMessage/retryMessage 的 (provider, model) 上下文，
  /// 用于在收到 Chunk 事件时为新建 assistant 消息打上模型标签。
  final Map<String, _SendContext> _sendContext = {};

  /// 已显式取消流式生成的会话集合。
  ///
  /// cancel 后旧流在途的 Done / Error 事件仍可能到达（事件已推入 sink），
  /// 需要忽略它们，避免误清掉新流的流式状态或触发队列自动发送。
  final Set<String> _cancelledStreams = {};

  /// cancel 后等待旧流在途事件落定的时间
  static const Duration _cancelSettleDelay = Duration(milliseconds: 50);

  /// 数据变更前的回调（供 ChatScrollObserver 记录位置）
  void Function()? onBeforeEmit;

  /// 全量变更（新增/删除消息 / 流完成）
  void _emit() {
    onBeforeEmit?.call();
    sessions.value = Map.from(sessions.value);
  }

  // ── 会话列表 ──

  /// 加载会话列表
  Future<void> loadSessions() async {
    sessionListLoading.value = true;
    try {
      sessionList.value = await LlmService().listSessions(
        dbPath: ConfigStore.instance.dbPath,
      );
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

  /// 重命名会话：先写 DB，再更新内存列表。
  Future<void> renameSession(String id, String newName) async {
    await LlmService().renameSession(
      dbPath: ConfigStore.instance.dbPath,
      sessionId: id,
      name: newName,
    );
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

  /// 删除会话（单个或批量）：删 DB → 清理选中/显示状态 → 移除内存数据。
  ///
  /// 各会话独立 try/catch，单个失败不影响其余删除。
  Future<void> deleteSessions(List<String> ids) async {
    if (ids.isEmpty) return;
    final service = LlmService();
    final dbPath = ConfigStore.instance.dbPath;

    for (final id in ids) {
      try {
        await service.deleteSession(dbPath: dbPath, sessionId: id);
      } catch (_) {
        // 继续删除其余会话
      }
    }

    // 清理选中/显示状态
    if (displayedSessionId.value != null &&
        ids.contains(displayedSessionId.value)) {
      displayedSessionId.value = null;
    }
    if (selectedId.value != null && ids.contains(selectedId.value)) {
      selectedId.value = null;
    }

    // 移除内存状态与订阅
    final map = Map<String, SessionState>.from(sessions.value);
    for (final id in ids) {
      map.remove(id);
      removeSession(id);
      unsubscribeSession(id);
      _sendContext.remove(id);
    }
    sessions.value = map;
  }

  // ── 状态访问 ──

  /// 快速访问当前会话的状态
  SessionState? stateFor(String? sessionId) =>
      sessionId != null ? sessions.value[sessionId] : null;

  /// 取消当前会话的流式生成
  Future<void> cancelStreaming(String sessionId) async {
    try {
      await LlmService().cancelStream(sessionId: sessionId);
    } catch (_) {}
    // 清理流状态（UI 立即恢复）
    _clearStreaming(sessionId);
    // 标记：旧流在途的 Done / Error 事件应被忽略（见 _onSessionEvent）
    _cancelledStreams.add(sessionId);
    _emit();
    // 等待旧流已推入事件管道的残留事件（尾部 chunk / Done）落定并被消费，
    // 保证调用方（如 Send Now）随后启动的新流不会与旧流事件交错。
    await Future<void>.delayed(_cancelSettleDelay);
  }

  // ── 操作 ──

  /// 创建新会话并设为当前会话
  Future<String> createSession() async {
    final now = DateTime.now();
    final name =
        '新对话 ${now.month}/${now.day} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final session = await LlmService().createSession(
      dbPath: ConfigStore.instance.dbPath,
      name: name,
    );
    addSession(session);
    selectedId.value = session.id;
    displayedSessionId.value = session.id;
    return session.id;
  }

  /// 创建新会话并切换（打开）到它 —— UI 层的「新建会话」统一入口。
  Future<String> createAndOpen() async {
    final id = await createSession();
    await switchTo(id);
    return id;
  }

  /// 发送用户输入 —— [ChatInput] 与消息队列「Send Now」的统一入口。
  ///
  /// 行为：
  /// 1. 当前会话流式输出中 → 自动入队，等回复结束后发送
  /// 2. 跟随当前智能体的模型配置（[AgentStore.resolveModel]）
  /// 3. 无会话时自动创建
  ///
  /// 返回是否真正发出（文本为空或模型未配置时返回 false）。
  Future<bool> sendPrompt(String text, {String? sessionId}) async {
    final trimmed = text.replaceAll('\n', '').trim();
    if (trimmed.isEmpty) return false;

    final sid = sessionId ?? selectedId.value;
    if (sid != null && streamingSessionIds.value.contains(sid)) {
      // 流式输出中 → 入队，等待当前回复结束后自动发送
      MessageQueueStore.instance.enqueue(trimmed);
      MessageQueueStore.instance.expand();
      return true;
    }

    final resolved = AgentStore.instance.resolveModel();
    if (resolved.provider.isEmpty || resolved.model.isEmpty) return false;

    final targetId = sid ?? await createSession();
    await sendMessage(
      sessionId: targetId,
      provider: resolved.provider,
      model: resolved.model,
      prompt: trimmed,
    );
    return true;
  }

  /// 切换到指定会话：订阅事件流 + 加载 DB 历史。
  ///
  /// 在统一 `ENGINE_SINK` 模型下，事件订阅是持续的（不依赖 stream lifecycle），
  /// 因此无需 buffer —— 切换会话期间产生的事件会立即通过订阅应用到状态。
  Future<void> switchTo(String sessionId) async {
    if (!sessions.value.containsKey(sessionId)) {
      sessions.value = {...sessions.value, sessionId: SessionState(sessionId)};
    }

    // ── 1. 订阅 session 事件流（如尚未订阅） ──
    _ensureSessionSubscription(sessionId);

    final service = LlmService();
    final dbPath = ConfigStore.instance.dbPath;

    // ── 2. 读 DB（parts + messages） ──
    await Future.wait([
      service
          .listMessagesBySession(dbPath: dbPath, sessionId: sessionId)
          .then((m) => sessions.value[sessionId]!.loadFromMessages(m))
          .catchError((_) {}),
      service
          .listPartsBySession(dbPath: dbPath, sessionId: sessionId)
          .then((p) => sessions.value[sessionId]!.loadFromParts(p))
          .catchError((_) {}),
    ]);

    _emit();
    displayedSessionId.value = sessionId;
  }

  /// 发送消息 — 触发后端 chat_stream，事件通过订阅异步到达。
  Future<void> sendMessage({
    required String sessionId,
    required String provider,
    required String model,
    required String prompt,
  }) async {
    final service = LlmService();
    final dbPath = ConfigStore.instance.dbPath;
    final configPath = AgentStore.instance.currentConfigPath.value;
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
        partType: PartTypes.text,
        content: prompt,
      ),
    ];
    s.messageRoles[userMsgId] = 'user';

    _emit();

    // ── 确保订阅 + 标记流式 ──
    _ensureSessionSubscription(sessionId);
    _sendContext[sessionId] = _SendContext(provider, model);
    // 新一轮流开始：清除取消标记，此后该会话的 Done / Error 视为新流事件
    _cancelledStreams.remove(sessionId);
    streamingSessionIds.value = {...streamingSessionIds.value, sessionId};
    _emit();

    // ── 触发后端任务（不 await Stream，事件通过 EngineClient 推送） ──
    try {
      // 系统提示词改为由后端从 system_prompt.md 读取，前端暂不注入
      // 保留以下代码供后续启用
      //
      // String? agentPrompt;
      // try {
      //   final raw = File(configPath).readAsStringSync();
      //   final cfg = jsonDecode(raw) as Map<String, dynamic>;
      //   agentPrompt = cfg['system_prompt'] as String?;
      // } catch (_) {}
      // final catalog = SkillStore.instance.buildSkillCatalog();
      // final systemPrompt = [
      //   if (agentPrompt != null && agentPrompt.isNotEmpty) agentPrompt,
      //   if (catalog.isNotEmpty) catalog,
      // ].join('\n\n');

      await service.chatStream(
        configPath: configPath,
        provider: provider,
        model: model,
        prompt: prompt,
        userMsgId: userMsgId,
        dbPath: dbPath,
        sessionId: sessionId,
      );
    } catch (e) {
      // 启动失败：追加错误消息并清理流状态
      StreamEventProcessor.appendPartContent(
        s,
        'err_${DateTime.now().millisecondsSinceEpoch}',
        '[错误] $e',
      );
      _clearStreaming(sessionId);
    }
    // 流式事件由 _ensureSessionSubscription 注册的 listener 异步应用
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
  }) async {
    final service = LlmService();
    final dbPath = ConfigStore.instance.dbPath;
    final configPath = AgentStore.instance.currentConfigPath.value;
    final s = _ensureState(sessionId);

    // 1. 更新本地用户消息的文本内容
    final parts = s.partsByMsg[msgId];
    if (parts != null) {
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].partType == PartTypes.text) {
          parts[i] = parts[i].copyWith(content: newPrompt);
        }
      }
    }

    _emit();

    // 2. 清理本地后续消息（后端会删除 DB 中的后续消息，本地也需要同步清除）
    final msgIndex = s.messageOrder.indexOf(msgId);
    if (msgIndex >= 0 && msgIndex + 1 < s.messageOrder.length) {
      final tailIds = s.messageOrder.sublist(msgIndex + 1);
      final tailPartIds = <String>{};
      for (final id in tailIds) {
        final parts = s.partsByMsg.remove(id);
        if (parts != null) {
          for (final p in parts) {
            tailPartIds.add(p.id);
          }
        }
        s.messageRoles.remove(id);
        s.messageModels.remove(id);
      }
      s.partLens.removeWhere((k, _) => tailPartIds.contains(k));
      s.reasoningPartLens.removeWhere((k, _) => tailPartIds.contains(k));
      s.messageOrder.removeRange(msgIndex + 1, s.messageOrder.length);
    }

    // 3. 触发后端重试（事件通过订阅异步到达）
    _ensureSessionSubscription(sessionId);
    _sendContext[sessionId] = _SendContext(provider, model);
    // 新一轮流开始：清除取消标记
    _cancelledStreams.remove(sessionId);
    streamingSessionIds.value = {...streamingSessionIds.value, sessionId};
    _emit();

    try {
      await service.chatRetry(
        configPath: configPath,
        provider: provider,
        model: model,
        msgId: msgId,
        chatText: newPrompt,
        sessionId: sessionId,
        dbPath: dbPath,
      );
    } catch (e) {
      StreamEventProcessor.appendPartContent(
        s,
        'err_${DateTime.now().millisecondsSinceEpoch}',
        '[错误] $e',
      );
      _clearStreaming(sessionId);
    }
  }

  // ── 事件订阅管理 ──

  /// 为指定 session 建立事件订阅（如已存在则跳过）。
  ///
  /// 订阅会持续到 [unsubscribeSession] 或应用退出。
  void _ensureSessionSubscription(String sessionId) {
    if (_sessionSubs.containsKey(sessionId)) return;

    final stream = EngineClient.instance.subscribeSession(sessionId);
    final s = _ensureState(sessionId);

    final sub = stream.listen(
      (event) => _onSessionEvent(sessionId, s, event),
      onError: (Object e, StackTrace st) {
        // 引擎层 onError 已处理，这里只重置流式状态
        _clearStreaming(sessionId);
      },
    );
    _sessionSubs[sessionId] = sub;
  }

  /// 关闭指定 session 的事件订阅（用于会话销毁或重置）。
  void unsubscribeSession(String sessionId) {
    _sessionSubs.remove(sessionId)?.cancel();
    EngineClient.instance.unsubscribeSession(sessionId);
    _cancelledStreams.remove(sessionId);
  }

  /// 单个事件应用到 session state。
  ///
  /// 处理 Chunk / ReasoningChunk / ToolCallFragment / ToolCall / Done / Error。
  /// FrontendToolCall 不在此处理（由 EngineClient 直接路由到 handler）。
  void _onSessionEvent(String sessionId, SessionState s, EngineEvent event) {
    // 被显式取消的旧流，其残留的终止事件（Done / Error）应被忽略：
    // 此时可能已有新流在运行（同一 sessionId），误处理会清掉新流的
    // 流式状态，或触发队列自动发送下一条消息。
    if (event is EngineEvent_Done || event is EngineEvent_Error) {
      if (_cancelledStreams.remove(sessionId)) return;
    }

    // 流式创建的 assistant 消息，记录模型名
    String? eMsgId;
    if (event is EngineEvent_Chunk) {
      eMsgId = event.msgId;
    } else if (event is EngineEvent_ReasoningChunk) {
      eMsgId = event.msgId;
    }

    if (event is EngineEvent_Done) {
      _clearStreaming(sessionId);
      _emit();

      // Done 后消费队列中的非 steer 消息（自动发出下一条）
      _consumeNonSteer(sessionId);
      return;
    }

    if (event is EngineEvent_QueueState) {
      // 用 Rust 队列状态刷新 UI 展示
      MessageQueueStore.instance.syncFromRust(event.items, event.flags);
      return;
    }

    if (event is EngineEvent_SteerInjected) {
      // Steer 消息被 checkpoint 注入到 LLM 上下文 → 在聊天中显示
      final steerMsgId =
          '${sessionId}_steer_${DateTime.now().millisecondsSinceEpoch}';
      s.messageOrder.add(steerMsgId);
      s.partsByMsg[steerMsgId] = [
        api.PartInfo(
          id: '${steerMsgId}_part',
          msgId: steerMsgId,
          seq: 0,
          partType: PartTypes.text,
          content: event.text,
        ),
      ];
      s.messageRoles[steerMsgId] = 'user';
      _emit();
      return;
    }

    if (event is EngineEvent_Error) {
      StreamEventProcessor.appendPartContent(
        s,
        'err_${DateTime.now().millisecondsSinceEpoch}',
        '[错误] ${event.message}',
      );
      _clearStreaming(sessionId);
      _emit();
      return;
    }

    // 应用 Chunk / ToolCallFragment / ToolCall / ReasoningChunk
    StreamEventProcessor.applyToState(s, event);

    // 记录 assistant 消息的模型标签（从最近一次 send 上下文取）
    if (eMsgId != null &&
        eMsgId.isNotEmpty &&
        !s.messageModels.containsKey(eMsgId)) {
      final ctx = _sendContext[sessionId];
      if (ctx != null) {
        final label = ctx.provider.isNotEmpty
            ? '${ctx.provider} / ${ctx.model}'
            : ctx.model;
        s.messageModels[eMsgId] = label;
      }
    }

    _emit();
  }

  /// Done 后从 Rust 队列消费非 steer 消息并自动发送
  void _consumeNonSteer(String sessionId) {
    unawaited(_doConsumeNonSteer(sessionId));
  }

  Future<void> _doConsumeNonSteer(String sessionId) async {
    final text = await api.consumeNonSteer(sessionId: sessionId);
    if (text == null) return;

    // 复用 sendPrompt 路径（跟随当前智能体的模型配置，失败静默）
    await sendPrompt(text, sessionId: sessionId);
  }

  /// 清理指定 session 的流式状态
  void _clearStreaming(String sessionId) {
    if (!streamingSessionIds.value.contains(sessionId)) return;
    streamingSessionIds.value = {
      for (final id in streamingSessionIds.value)
        if (id != sessionId) id,
    };
  }

  SessionState _ensureState(String sessionId) {
    if (!sessions.value.containsKey(sessionId)) {
      sessions.value = {...sessions.value, sessionId: SessionState(sessionId)};
    }
    return sessions.value[sessionId]!;
  }

  void dispose() {
    for (final sub in _sessionSubs.values) {
      sub.cancel();
    }
    _sessionSubs.clear();
  }
}

/// 一次 sendMessage / retryMessage 的 (provider, model) 上下文。
class _SendContext {
  final String provider;
  final String model;
  _SendContext(this.provider, this.model);
}
