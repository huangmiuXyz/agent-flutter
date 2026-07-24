/// Provider list page — shows all available model providers in an [AppBigList].
///
/// Uses the real [api.listProviders] data via [providersList] Riverpod provider.
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/features/settings/models/provider_info.dart';
import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/services/llm/llm_providers.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/list/app_big_list.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Displays all providers in an [AppBigList] with search and status dots.
class ProviderListPage extends HookConsumerWidget {
  /// Called when the user taps a provider row.
  final ValueChanged<ProviderInfo> onProviderTap;

  /// Called when the user wants to add a custom provider.
  final VoidCallback? onAddProvider;

  const ProviderListPage({super.key, required this.onProviderTap, this.onAddProvider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Load providers from Rust backend ──
    final providersAsync = ref.watch(providersListProvider);

    return providersAsync.when(
      data: (providers) => _buildList(providers),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) =>
          Center(child: AppText('加载失败: $err', variant: AppTextVariant.body)),
    );
  }

  Widget _buildList(List<api.ProviderSummary> providers) {
    final providerInfos = providers.map(ProviderInfo.fromRust).toList();

    // ── Search ──
    final searchQuery = useState('');
    final query = searchQuery.value.trim().toLowerCase();

    bool matches(ProviderInfo p) {
      if (query.isEmpty) return true;
      return p.label.toLowerCase().contains(query) ||
          p.name.toLowerCase().contains(query);
    }

    final configured = providerInfos
        .where((p) => p.configured && matches(p))
        .toList();
    final unconfigured = providerInfos
        .where((p) => !p.configured && matches(p))
        .toList();
    final total = configured.length + unconfigured.length;

    // Build groups
    final groups = <Widget>[];
    if (configured.isNotEmpty) {
      groups.add(
        AppBigGroup(
          label: '已配置',
          children: [
            for (final p in configured)
              _providerRow(p, onProviderTap: onProviderTap),
          ],
        ),
      );
    }
    if (unconfigured.isNotEmpty) {
      groups.add(
        AppBigGroup(
          label: '未配置',
          children: [
            for (final p in unconfigured)
              _providerRow(p, onProviderTap: onProviderTap),
          ],
        ),
      );
    }

    return ContentFrame(
      child: AppBigList(
        count: total,
        countLabel: '个提供商',
        showSearch: true,
        searchTerm: searchQuery.value,
        onSearchChanged: (v) => searchQuery.value = v,
        searchPlaceholder: '搜索提供商...',
        actions: [
          AppPrimaryButton(
            text: '添加提供商',
            size: ButtonSize.sm,
            onPressed: onAddProvider,
          ),
        ],
        emptyState: AppBigEmpty(
          icon: 'search',
          title: query.isEmpty ? '暂无可用提供商' : '没有匹配的提供商',
          hint: query.isEmpty ? '' : '试试其他关键词',
        ),
        children: groups,
      ),
    );
  }

  Widget _providerRow(
    ProviderInfo provider, {
    required ValueChanged<ProviderInfo> onProviderTap,
  }) {
    return AppBigRow(
      name: provider.label,
      description: provider.baseUrl,
      dot: provider.configured,
      dotColor: provider.configured ? null : Colors.transparent,
      leading: _ProviderAvatar(name: provider.label),
      clickable: true,
      onTap: () => onProviderTap(provider),
    );
  }
}

/// Simple avatar showing the first letter of the provider name.
class _ProviderAvatar extends StatelessWidget {
  final String name;
  const _ProviderAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        color: Colors.primaries[name.hashCode % Colors.primaries.length]
            .withValues(alpha: 0.2)
      ),
      child: Center(
        child: AppText(name[0].toUpperCase(), variant: AppTextVariant.body),
      ),
    );
  }
}
