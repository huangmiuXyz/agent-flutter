/// LLM Service Riverpod Providers
///
/// 提供 `LlmService` 的全局单例以及与 UI 状态绑定的 providers。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:agent/rust_bridge/api.dart' as api;

import 'llm_service.dart';
import 'session_manager.dart';

part 'llm_providers.g.dart';

/// LLM 服务实例（全局单例）
@riverpod
LlmService llmService(Ref ref) {
  return LlmService();
}

/// LLM 初始化状态
@riverpod
class LlmInit extends _$LlmInit {
  @override
  Future<void> build() async {
    await ref.read(llmServiceProvider).init();
  }
}

/// 配置路径（可外部覆盖）
@riverpod
class ConfigPath extends _$ConfigPath {
  @override
  String build() => 'config.json';
}

/// 数据库路径（可外部覆盖）
@riverpod
class DbPath extends _$DbPath {
  @override
  String build() => './data/data';
}

/// 会话列表
@riverpod
Future<List<api.SessionInfo>> sessions(Ref ref) async {
  final service = ref.watch(llmServiceProvider);
  final dbPath = ref.watch(dbPathProvider);
  await ref.watch(llmInitProvider.future);
  return service.listSessions(dbPath: dbPath);
}

/// 当前选中的会话 ID
@riverpod
class SelectedSession extends _$SelectedSession {
  @override
  String? build() => null;

  void select(String? sessionId) => state = sessionId;
}

/// SessionManager 全局单例
final sessionManagerProvider = StateNotifierProvider<SessionManager, Map<String, SessionState>>((ref) {
  return SessionManager(ref);
});

/// 当前活跃会话的 state（方便 UI 监听）
final activeSessionStateProvider = Provider<SessionState?>((ref) {
  final selectedId = ref.watch(selectedSessionProvider);
  final allStates = ref.watch(sessionManagerProvider);
  if (selectedId == null) return null;
  return allStates[selectedId];
});
