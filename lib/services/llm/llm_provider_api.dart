/// LLM 提供商与模型 API
library;

import 'package:agent/rust_bridge/api/providers.dart' as api;
import 'package:agent/rust_bridge/api/types.dart' as api;

import 'llm_shared.dart';

/// 提供商与模型相关 API
mixin ProviderModelApi on GuardedApi {
  /// 列出所有可用的 AI 提供商
  Future<List<api.ProviderSummary>> listProviders({
    required String configPath,
  }) =>
      guard(
        '获取提供商列表失败',
        () => api.listProviders(configPath: configPath),
      );

  /// 列出指定厂商的可用模型
  Future<List<String>> listModels({
    required String provider,
    required String configPath,
  }) =>
      guard(
        '获取模型列表失败',
        () => api.listModels(provider: provider, configPath: configPath),
      );
}
