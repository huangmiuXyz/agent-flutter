/// LLM 聊天 API（流式与非流式）
library;

import 'package:agent/rust_bridge/api.dart' as api;

import 'llm_shared.dart';

/// 聊天相关 API
mixin ChatApi {
  /// 子类必须提供初始化检查
  void ensureInitialized();

  /// 发送聊天消息，等待完整回复
  Future<String> chat({
    required String configPath,
    required String provider,
    required String model,
    required String prompt,
    String? dbPath,
    String? sessionId,
  }) async {
    ensureInitialized();
    try {
      final result = await api.chat(
        configPath: configPath,
        provider: provider,
        model: model,
        prompt: prompt,
        dbPath: dbPath,
        sessionId: sessionId,
      );
      return result.text;
    } catch (e) {
      throw LlmException('聊天失败: $e');
    }
  }

  /// 发送聊天消息，以流式接收回复
  Stream<api.StreamEvent> chatStream({
    required String configPath,
    required String provider,
    required String model,
    required String prompt,
    String? dbPath,
    String? sessionId,
  }) {
    ensureInitialized();
    try {
      return api.chatStream(
        configPath: configPath,
        provider: provider,
        model: model,
        prompt: prompt,
        dbPath: dbPath,
        sessionId: sessionId,
      );
    } catch (e) {
      return Stream.value(api.StreamEvent.error('启动流式聊天失败: $e'));
    }
  }
}
