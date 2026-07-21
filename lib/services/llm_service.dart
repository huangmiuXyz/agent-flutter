/// Agent LLM Service
///
/// 提供层，封装 `flutter_rust_bridge` 生成的 Rust API 调用，
/// 在 Dart 侧提供类型安全、错误清晰的接口。
library;

import 'package:agent/rust_bridge/frb_generated.dart' as frb;
import 'package:agent/rust_bridge/api.dart' as api;

/// LLM 服务 — 所有与 Rust 引擎的交互通过此类进行
class LlmService {
  bool _initialized = false;

  /// 初始化 Rust 引擎（FRB 运行时）
  Future<void> init() async {
    if (_initialized) return;
    await frb.RustLib.init();
    _initialized = true;
  }

  // ─── 提供商 ─────────────────────────────────────────

  /// 列出所有可用的 AI 提供商
  Future<List<api.ProviderSummary>> listProviders({
    required String configPath,
  }) async {
    _ensureInitialized();
    try {
      return await api.listProviders(configPath: configPath);
    } catch (e) {
      throw LlmException('获取提供商列表失败: $e');
    }
  }

  // ─── 模型 ───────────────────────────────────────────

  /// 列出指定厂商的可用模型
  Future<List<String>> listModels({
    required String provider,
    required String configPath,
  }) async {
    _ensureInitialized();
    try {
      return await api.listModels(provider: provider, configPath: configPath);
    } catch (e) {
      throw LlmException('获取模型列表失败: $e');
    }
  }

  // ─── 非流式聊天 ─────────────────────────────────────

  /// 发送聊天消息，等待完整回复
  Future<String> chat({
    required String configPath,
    required String provider,
    required String model,
    required String prompt,
    String? dbPath,
    String? sessionId,
  }) async {
    _ensureInitialized();
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

  // ─── 流式聊天 ───────────────────────────────────────

  /// 发送聊天消息，以流式接收回复
  Stream<api.StreamEvent> chatStream({
    required String configPath,
    required String provider,
    required String model,
    required String prompt,
    String? dbPath,
    String? sessionId,
  }) {
    _ensureInitialized();
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

  // ─── 会话管理 ───────────────────────────────────────

  /// 创建新会话
  Future<api.SessionInfo> createSession({
    required String dbPath,
    required String name,
  }) async {
    _ensureInitialized();
    try {
      return await api.createSession(dbPath: dbPath, name: name);
    } catch (e) {
      throw LlmException('创建会话失败: $e');
    }
  }

  /// 删除会话
  Future<void> deleteSession({
    required String dbPath,
    required String sessionId,
  }) async {
    _ensureInitialized();
    try {
      await api.deleteSession(dbPath: dbPath, sessionId: sessionId);
    } catch (e) {
      throw LlmException('删除会话失败: $e');
    }
  }

  /// 获取单个会话详情
  Future<api.SessionInfo> getSession({
    required String dbPath,
    required String sessionId,
  }) async {
    _ensureInitialized();
    try {
      return await api.getSession(dbPath: dbPath, sessionId: sessionId);
    } catch (e) {
      throw LlmException('获取会话失败: $e');
    }
  }

  /// 列出所有会话
  Future<List<api.SessionInfo>> listSessions({required String dbPath}) async {
    _ensureInitialized();
    try {
      return await api.listSessions(dbPath: dbPath);
    } catch (e) {
      throw LlmException('获取会话列表失败: $e');
    }
  }

  // ─── 实时订阅 ───────────────────────────────────────

  /// 订阅一个会话的实时事件
  Stream<api.StreamEvent> subscribeSession({
    required String dbPath,
    required String sessionId,
  }) {
    _ensureInitialized();
    try {
      return api.subscribeSession(dbPath: dbPath, sessionId: sessionId);
    } catch (e) {
      return Stream.value(api.StreamEvent.error('订阅失败: $e'));
    }
  }

  // ─── 数据读取 ───────────────────────────────────────

  /// 读取单个 part 的完整内容
  Future<String> readPart({
    required String dbPath,
    required String partId,
  }) async {
    _ensureInitialized();
    try {
      return await api.readPart(dbPath: dbPath, partId: partId);
    } catch (e) {
      throw LlmException('读取 part 失败: $e');
    }
  }

  /// 列出某个会话的所有 messages
  Future<List<api.MessageInfo>> listMessagesBySession({
    required String dbPath,
    required String sessionId,
  }) async {
    _ensureInitialized();
    try {
      return await api.listMessagesBySession(dbPath: dbPath, sessionId: sessionId);
    } catch (e) {
      throw LlmException('获取消息列表失败: $e');
    }
  }

  /// 列出某个会话的所有 parts（含完整内容）
  Future<List<api.PartInfo>> listPartsBySession({
    required String dbPath,
    required String sessionId,
  }) async {
    _ensureInitialized();
    try {
      return await api.listPartsBySession(dbPath: dbPath, sessionId: sessionId);
    } catch (e) {
      throw LlmException('获取 part 列表失败: $e');
    }
  }

  // ─── 内部辅助 ───────────────────────────────────────

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('LlmService 未初始化，请先调用 init()');
    }
  }
}

/// LLM 服务异常
class LlmException implements Exception {
  final String message;
  const LlmException(this.message);

  @override
  String toString() => 'LlmException: $message';
}
