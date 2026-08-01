/// LLM 聊天 API（流式与非流式）
///
/// 注意：在统一 `ENGINE_SINK` 模型下，`chatStream` / `chatRetry` 调用后
/// 仅触发后端任务（不返回 Stream），事件通过 [EngineClient] 推送。
/// 调用方应先订阅 [EngineClient.subscribeSession] 再调用本 API。
library;

import 'package:agent/rust_bridge/api.dart' as api;

import 'llm_shared.dart';

/// 聊天相关 API
mixin ChatApi on GuardedApi {
  /// 发送聊天消息，等待完整回复（非流式）
  Future<String> chat({
    required String configPath,
    required String provider,
    required String model,
    required String prompt,
    String? dbPath,
    String? sessionId,
    String? systemPrompt,
  }) async {
    final result = await guard(
      '聊天失败',
      () => api.chat(
        configPath: configPath,
        provider: provider,
        model: model,
        prompt: prompt,
        dbPath: dbPath,
        sessionId: sessionId,
        systemPrompt: systemPrompt,
      ),
    );
    return result.text;
  }

  /// 发送聊天消息（流式）— 触发后端任务，事件通过 [EngineClient] 推送。
  ///
  /// 调用前应先通过 `EngineClient.instance.subscribeSession(sessionId)`
  /// 订阅事件，否则会错过 Chunk / ToolCall / Done / Error 等事件。
  ///
  /// 返回的 Future 仅表示「请求已派发」，不代表流结束。
  Future<void> chatStream({
    required String configPath,
    required String provider,
    required String model,
    required String prompt,
    String? userMsgId,
    String? dbPath,
    String? sessionId,
    String? systemPrompt,
  }) =>
      guard(
        '启动流式聊天失败',
        () => api.chatStream(
          configPath: configPath,
          provider: provider,
          model: model,
          prompt: prompt,
          userMsgId: userMsgId,
          dbPath: dbPath,
          sessionId: sessionId,
          systemPrompt: systemPrompt,
        ),
      );

  /// 重试（编辑）用户消息：替换内容后重新流式请求 LLM。
  ///
  /// 行为同 [chatStream] — 事件通过 [EngineClient] 推送。
  Future<void> chatRetry({
    required String configPath,
    required String provider,
    required String model,
    required String msgId,
    required String chatText,
    required String sessionId,
    String? dbPath,
  }) =>
      guard(
        '重试失败',
        () => api.chatRetry(
          configPath: configPath,
          provider: provider,
          model: model,
          msgId: msgId,
          chatText: chatText,
          sessionId: sessionId,
          dbPath: dbPath,
        ),
      );
}
