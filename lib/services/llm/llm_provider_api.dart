/// LLM 提供商与模型 API
library;

import 'package:agent/rust_bridge/api.dart' as api;

import 'llm_shared.dart';

/// 提供商与模型相关 API
mixin ProviderModelApi {
  /// 子类必须提供初始化检查
  void ensureInitialized();

  /// 列出所有可用的 AI 提供商
  Future<List<api.ProviderSummary>> listProviders({
    required String configPath,
  }) async {
    ensureInitialized();
    try {
      return await api.listProviders(configPath: configPath);
    } catch (e) {
      throw LlmException('获取提供商列表失败: $e');
    }
  }

  /// 列出指定厂商的可用模型
  Future<List<String>> listModels({
    required String provider,
    required String configPath,
  }) async {
    ensureInitialized();
    try {
      return await api.listModels(provider: provider, configPath: configPath);
    } catch (e) {
      throw LlmException('获取模型列表失败: $e');
    }
  }
}
