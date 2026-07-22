/// LLM Service Riverpod Providers
///
/// 提供 `LlmService` 的全局单例以及与 UI 状态绑定的 providers。
library;

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:agent/rust_bridge/api.dart' as api;

export 'config_service.dart';

import 'config_service.dart';
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
@riverpod
SessionManager sessionManager(Ref ref) {
  final manager = SessionManager(ref);
  ref.onDispose(() => manager.dispose());
  return manager;
}

/// 当前活跃会话的 state（方便 UI 监听）
@riverpod
SessionState? activeSessionState(Ref ref) {
  final selectedId = ref.watch(selectedSessionProvider);
  if (selectedId == null) return null;
  final manager = ref.watch(sessionManagerProvider);
  return manager.state[selectedId];
}

/// 当前使用的 LLM 提供商（启动时从 DefaultModel store 读取默认值）
@riverpod
class CurrentProvider extends _$CurrentProvider {
  @override
  String build() {
    final config = ref.read(defaultModelProvider);
    if (config != null) {
      return config['provider']!;
    }
    return '';
  }

  void select(String provider) => state = provider;
}

/// 当前使用的 LLM 模型（启动时从 DefaultModel store 读取默认值）
@riverpod
class CurrentModel extends _$CurrentModel {
  @override
  String build() {
    final config = ref.read(defaultModelProvider);
    if (config != null) {
      return config['model']!;
    }
    return '';
  }

  void select(String model) => state = model;
}

/// 可用提供商列表（自动加载）
@riverpod
Future<List<api.ProviderSummary>> providersList(Ref ref) async {
  final service = ref.watch(llmServiceProvider);
  final configPath = ref.watch(configPathProvider);
  await ref.watch(llmInitProvider.future);
  return service.listProviders(configPath: configPath);
}

/// 当前提供商下的可用模型列表（自动加载）
@riverpod
Future<List<String>> modelsList(Ref ref) async {
  final provider = ref.watch(currentProviderProvider);
  if (provider.isEmpty) return [];
  final service = ref.watch(llmServiceProvider);
  final configPath = ref.watch(configPathProvider);
  await ref.watch(llmInitProvider.future);
  return service.listModels(provider: provider, configPath: configPath);
}
