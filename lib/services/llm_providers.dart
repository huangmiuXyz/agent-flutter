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
final sessionManagerProvider = Provider<SessionManager>((ref) {
  final manager = SessionManager(ref);
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// 当前活跃会话的 state（方便 UI 监听）
final activeSessionStateProvider = Provider<SessionState?>((ref) {
  final selectedId = ref.watch(selectedSessionProvider);
  if (selectedId == null) return null;
  final manager = ref.watch(sessionManagerProvider);
  return manager.state[selectedId];
});

/// 当前使用的 LLM 提供商
class _CurrentProvider extends Notifier<String> {
  @override
  String build() => '';

  void select(String provider) => state = provider;
}

final currentProviderProvider = NotifierProvider<_CurrentProvider, String>(
  _CurrentProvider.new,
);

/// 当前使用的 LLM 模型
class _CurrentModel extends Notifier<String> {
  @override
  String build() => '';

  void select(String model) => state = model;
}

final currentModelProvider = NotifierProvider<_CurrentModel, String>(
  _CurrentModel.new,
);

/// 可用提供商列表（自动加载）
final providersListProvider = FutureProvider<List<api.ProviderSummary>>((
  ref,
) async {
  final service = ref.watch(llmServiceProvider);
  final configPath = ref.watch(configPathProvider);
  await ref.watch(llmInitProvider.future);
  return service.listProviders(configPath: configPath);
});

/// 当前提供商下的可用模型列表（自动加载）
final modelsListProvider = FutureProvider<List<String>>((ref) async {
  final provider = ref.watch(currentProviderProvider);
  if (provider.isEmpty) return [];
  final service = ref.watch(llmServiceProvider);
  final configPath = ref.watch(configPathProvider);
  await ref.watch(llmInitProvider.future);
  return service.listModels(provider: provider, configPath: configPath);
});
