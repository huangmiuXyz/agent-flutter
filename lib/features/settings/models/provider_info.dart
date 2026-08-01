/// Provider data model for the settings UI.
///
/// Mirrors [api.ProviderSummary] with extra client-side state.
library;

import 'package:agent/rust_bridge/api.dart' as api;

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

/// 提供商名称 → config.json 中 `language_models` 的协议键。
///
/// - Anthropic → `anthropic`
/// - 其他 → `openai_compatible`
String protocolForProvider(String name) {
  if (name == 'Anthropic') return 'anthropic';
  return 'openai_compatible';
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
