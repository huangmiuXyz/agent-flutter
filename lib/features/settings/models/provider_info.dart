/// Provider data model for the settings UI.
///
/// Mirrors [api.ProviderSummary] with extra client-side state.
library;

import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/widgets/select/app_select.dart';

/// Thin wrapper around [api.ProviderSummary] with display helpers.
class ProviderInfo {
  final String name;
  final String? displayName;
  final String? baseUrl;
  final bool configured;

  const ProviderInfo({
    required this.name,
    this.displayName,
    this.baseUrl,
    this.configured = false,
  });

  /// Human-readable label: prefer displayName, fallback to name.
  String get label => displayName ?? name;

  factory ProviderInfo.fromRust(api.ProviderSummary p) => ProviderInfo(
    name: p.name,
    displayName: p.displayName,
    baseUrl: p.baseUrl,
    configured: p.configured,
  );
}

/// 协议类型选项：值 = config.json 的 `language_models` 段名。
const protocolOptions = [
  AppSelectOption<String>(value: 'openai_compatible', label: 'OpenAI 兼容'),
  AppSelectOption<String>(value: 'anthropic', label: 'Anthropic 原生'),
  AppSelectOption<String>(value: 'responses', label: 'OpenAI Responses'),
];

/// 提供商名称 → 默认协议键（无配置时的推断）。
///
/// - Anthropic → `anthropic`
/// - 其他 → `openai_compatible`
String protocolForProvider(String name) {
  if (name == 'Anthropic') return 'anthropic';
  return 'openai_compatible';
}

/// 从 config 的 `language_models` 中查找指定 provider 的完整配置，
/// 不关心它当前在哪个协议段（`openai_compatible` / `anthropic` / `responses`）。
/// 找不到返回 null。
Map<String, dynamic>? findProviderConfig(
  Map<String, dynamic> data,
  String providerId,
) {
  final lm = data['language_models'];
  if (lm is! Map<String, dynamic>) return null;
  for (final proto in lm.values) {
    if (proto is! Map<String, dynamic>) continue;
    final cfg = proto[providerId];
    if (cfg is Map<String, dynamic>) return cfg;
  }
  return null;
}

/// 检测 provider 在 config 的 `language_models` 中所处的协议段。
/// 找不到返回 null（调用方回退到按名称推断）。
String? protocolFromConfig(Map<String, dynamic> data, String providerId) {
  final lm = data['language_models'];
  if (lm is! Map<String, dynamic>) return null;
  for (final entry in lm.entries) {
    final proto = entry.value;
    if (proto is Map<String, dynamic> && proto.containsKey(providerId)) {
      return entry.key;
    }
  }
  return null;
}

/// 从智能体自包含 config 中检测 provider 所在的协议段。
/// 检测不到时返回 null（调用方回退到按名称推断）。
String? protocolFromAgentConfig(
  Map<String, dynamic> cfg,
  String? providerId,
) {
  if (providerId == null) return null;
  return protocolFromConfig(cfg, providerId);
}

/// 从 config.json 的 `language_models` 结构解析提供商 → 可用模型名列表。
///
/// 结构：`language_models.{protocol}.{provider}.available_models`，
/// `available_models` 的元素可以是字符串或 `{"name": "..."}` map。
Map<String, List<String>> parseProviderModels(Map<String, dynamic> data) {
  final result = <String, List<String>>{};
  final lm = data['language_models'];
  if (lm is! Map<String, dynamic>) return result;
  for (final proto in lm.values) {
    if (proto is! Map<String, dynamic>) continue;
    for (final entry in proto.entries) {
      final cfg = entry.value;
      if (cfg is! Map<String, dynamic>) continue;
      final raw = cfg['available_models'] as List<dynamic>?;
      if (raw == null) continue;
      final names = raw
          .map((e) => e is Map ? e['name']?.toString() : e.toString())
          .whereType<String>()
          .where((n) => n.isNotEmpty)
          .toList();
      result.putIfAbsent(entry.key, () => []).addAll(names);
    }
  }
  return result;
}
