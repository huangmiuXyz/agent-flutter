/// LLM 会话管理 API（CRUD、数据读取、前端工具注册）
///
/// 注意：在统一 `ENGINE_SINK` 模型下，已无 `subscribeSession`。
/// 事件订阅通过 [EngineClient.subscribeSession] 完成。
library;

import 'package:agent/rust_bridge/api.dart' as api;

import 'llm_shared.dart';

/// 会话相关 API — CRUD、数据读取、前端工具注册
mixin SessionApi on GuardedApi {
  // ─── CRUD ───────────────────────────────────────────

  /// 创建新会话
  Future<api.SessionInfo> createSession({
    required String dbPath,
    required String name,
  }) =>
      guard(
        '创建会话失败',
        () => api.createSession(dbPath: dbPath, name: name),
      );

  /// 重命名会话
  Future<api.SessionInfo> renameSession({
    required String dbPath,
    required String sessionId,
    required String name,
  }) =>
      guard(
        '重命名会话失败',
        () => api.renameSession(
          dbPath: dbPath,
          sessionId: sessionId,
          name: name,
        ),
      );

  /// 删除会话
  Future<void> deleteSession({
    required String dbPath,
    required String sessionId,
  }) =>
      guard(
        '删除会话失败',
        () => api.deleteSession(dbPath: dbPath, sessionId: sessionId),
      );

  /// 获取单个会话详情
  Future<api.SessionInfo> getSession({
    required String dbPath,
    required String sessionId,
  }) =>
      guard(
        '获取会话失败',
        () => api.getSession(dbPath: dbPath, sessionId: sessionId),
      );

  /// 列出所有会话
  Future<List<api.SessionInfo>> listSessions({required String dbPath}) =>
      guard('获取会话列表失败', () => api.listSessions(dbPath: dbPath));

  // ─── 取消流 ───────────────────────────────────────

  /// 取消正在进行的流式生成
  Future<void> cancelStream({
    required String sessionId,
  }) =>
      guard('取消流失败', () => api.cancelStream(sessionId: sessionId));

  // ─── 数据读取 ───────────────────────────────────────

  /// 读取单个 part 的完整内容
  Future<String> readPart({
    required String dbPath,
    required String partId,
  }) =>
      guard('读取 part 失败', () => api.readPart(dbPath: dbPath, partId: partId));

  /// 列出某个会话的所有 messages
  Future<List<api.MessageInfo>> listMessagesBySession({
    required String dbPath,
    required String sessionId,
  }) =>
      guard(
        '获取消息列表失败',
        () => api.listMessagesBySession(dbPath: dbPath, sessionId: sessionId),
      );

  /// 列出某个会话的所有 parts（含完整内容）
  Future<List<api.PartInfo>> listPartsBySession({
    required String dbPath,
    required String sessionId,
  }) =>
      guard(
        '获取 part 列表失败',
        () => api.listPartsBySession(dbPath: dbPath, sessionId: sessionId),
      );

  // ─── 前端工具注册 ─────────────────────────────────

  /// 注册一个前端工具。LLM 在 chat 中可调用该工具，调用时通过
  /// `EngineEvent_FrontendToolCall` 推送到 Flutter，Flutter 执行后通过
  /// [submitFrontendToolResult] 回传结果。
  ///
  /// - `name`: 工具名（唯一，重复注册会覆盖）
  /// - `description`: 工具描述（LLM 看到的）
  /// - `parameters`: JSON Schema 字符串，描述入参
  Future<void> registerFrontendTool({
    required String name,
    required String description,
    required String parameters,
  }) =>
      guard(
        '注册前端工具失败',
        () => api.registerFrontendTool(
          name: name,
          description: description,
          parameters: parameters,
        ),
      );

  /// 注销一个前端工具。返回 true 表示成功注销；false 表示工具不存在。
  Future<bool> unregisterFrontendTool({required String name}) =>
      guard('注销前端工具失败', () => api.unregisterFrontendTool(name: name));

  /// 提交前端工具调用的结果。
  ///
  /// Flutter 收到 `EngineEvent_FrontendToolCall` 后，执行工具（如弹终端、
  /// UI 交互），然后调用此 API 把结果回传给 Rust，恢复挂起的
  /// `FrontendTool::execute()`，LLM 继续生成。
  ///
  /// 返回 true 表示成功匹配并完成；false 表示 call_id 不存在（可能已超时或被取消）。
  Future<bool> submitFrontendToolResult({
    required String callId,
    required String result,
  }) =>
      guard(
        '提交前端工具结果失败',
        () => api.submitFrontendToolResult(callId: callId, result: result),
      );
}
