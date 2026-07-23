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
