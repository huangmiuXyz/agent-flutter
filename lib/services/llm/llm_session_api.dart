/// LLM 会话管理 API（CRUD、数据读取、实时订阅）
library;

import 'package:agent/rust_bridge/api.dart' as api;

import 'llm_shared.dart';

/// 会话相关 API — CRUD、数据读取、实时订阅
mixin SessionApi {
  /// 子类必须提供初始化检查
  void ensureInitialized();

  // ─── CRUD ───────────────────────────────────────────

  /// 创建新会话
  Future<api.SessionInfo> createSession({
    required String dbPath,
    required String name,
  }) async {
    ensureInitialized();
    try {
      return await api.createSession(dbPath: dbPath, name: name);
    } catch (e) {
      throw LlmException('创建会话失败: $e');
    }
  }

  /// 重命名会话
  Future<api.SessionInfo> renameSession({
    required String dbPath,
    required String sessionId,
    required String name,
  }) async {
    ensureInitialized();
    try {
      return await api.renameSession(
        dbPath: dbPath,
        sessionId: sessionId,
        name: name,
      );
    } catch (e) {
      throw LlmException('重命名会话失败: $e');
    }
  }

  /// 删除会话
  Future<void> deleteSession({
    required String dbPath,
    required String sessionId,
  }) async {
    ensureInitialized();
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
    ensureInitialized();
    try {
      return await api.getSession(dbPath: dbPath, sessionId: sessionId);
    } catch (e) {
      throw LlmException('获取会话失败: $e');
    }
  }

  /// 列出所有会话
  Future<List<api.SessionInfo>> listSessions({required String dbPath}) async {
    ensureInitialized();
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
    ensureInitialized();
    try {
      return api.subscribeSession(dbPath: dbPath, sessionId: sessionId);
    } catch (e) {
      return Stream.value(api.StreamEvent.error('订阅失败: $e'));
    }
  }

  // ─── 取消流 ───────────────────────────────────────

  /// 取消正在进行的流式生成
  Future<void> cancelStream({
    required String sessionId,
  }) async {
    ensureInitialized();
    try {
      await api.cancelStream(sessionId: sessionId);
    } catch (e) {
      throw LlmException('取消流失败: $e');
    }
  }

  // ─── 数据读取 ───────────────────────────────────────

  /// 读取单个 part 的完整内容
  Future<String> readPart({
    required String dbPath,
    required String partId,
  }) async {
    ensureInitialized();
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
    ensureInitialized();
    try {
      return await api.listMessagesBySession(
        dbPath: dbPath,
        sessionId: sessionId,
      );
    } catch (e) {
      throw LlmException('获取消息列表失败: $e');
    }
  }

  /// 列出某个会话的所有 parts（含完整内容）
  Future<List<api.PartInfo>> listPartsBySession({
    required String dbPath,
    required String sessionId,
  }) async {
    ensureInitialized();
    try {
      return await api.listPartsBySession(dbPath: dbPath, sessionId: sessionId);
    } catch (e) {
      throw LlmException('获取 part 列表失败: $e');
    }
  }
}
