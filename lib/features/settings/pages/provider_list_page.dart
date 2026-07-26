/// Provider list page — shows all available model providers in an [AppBigList].
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/features/settings/models/provider_info.dart';
import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/store/config_store.dart';
import 'package:agent/services/llm/llm_service.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/utils/file_utils.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/list/app_big_list.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Displays all providers in an [AppBigList] with search and status dots.
class ProviderListPage extends HookWidget {
  /// Called when the user taps a provider row.
  final ValueChanged<ProviderInfo> onProviderTap;

  /// Called when the user wants to add a custom provider.
  final VoidCallback? onAddProvider;

  const ProviderListPage({
    super.key,
    required this.onProviderTap,
    this.onAddProvider,
  });

  @override
  Widget build(BuildContext context) {
    final configPath = ConfigStore.instance.configPath;
    final providers = useState<List<api.ProviderSummary>>([]);
    final loading = useState(true);

    useEffect(() {
      Future<void> load() async {
        loading.value = true;
        try {
          providers.value = await LlmService().listProviders(
            configPath: configPath,
          );
        } finally {
          loading.value = false;
        }
      }

      load();
      return null;
    }, [configPath]);

    if (loading.value) {
      return const Center(child: CircularProgressIndicator());
    }

    return _buildList(providers.value, configPath);
  }

  Widget _buildList(List<api.ProviderSummary> providers, String configPath) {
    final searchQuery = useState('');
    final query = searchQuery.value.trim().toLowerCase();

    // ── Memoized filtering ──
    bool matches(ProviderInfo p) {
      if (query.isEmpty) return true;
      return p.label.toLowerCase().contains(query) ||
          p.name.toLowerCase().contains(query);
    }

    // Filter once — section builders reference these closures lazily.
    final configured = <ProviderInfo>[];
    final unconfigured = <ProviderInfo>[];
    for (final p in providers.map(ProviderInfo.fromRust)) {
      if (!matches(p)) continue;
      if (p.configured) {
        configured.add(p);
      } else {
        unconfigured.add(p);
      }
    }
    final total = configured.length + unconfigured.length;

    // ── Build sections (lazy — only visible items are built) ──
    final sections = <AppBigSection>[];
    if (configured.isNotEmpty) {
      sections.add(
        AppBigSection(
          label: '已配置',
          itemCount: configured.length,
          itemBuilder: (ctx, i, {required isFirst, required isLast}) =>
              _providerRow(configured[i], onProviderTap: onProviderTap),
        ),
      );
    }
    if (unconfigured.isNotEmpty) {
      sections.add(
        AppBigSection(
          label: '未配置',
          itemCount: unconfigured.length,
          itemBuilder: (ctx, i, {required isFirst, required isLast}) =>
              _providerRow(unconfigured[i], onProviderTap: onProviderTap),
        ),
      );
    }

    return ContentFrame(
      scrollable: sections.isEmpty,
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
          const SizedBox(width: 8),
          AppSecondaryButton(
            text: '配置文件',
            icon: 'fileCode',
            size: ButtonSize.sm,
            onPressed: () => openFile(configPath),
          ),
        ],
        emptyState: AppBigEmpty(
          icon: 'search',
          title: query.isEmpty ? '暂无可用提供商' : '没有匹配的提供商',
          hint: query.isEmpty ? '' : '试试其他关键词',
        ),
        sections: sections.isNotEmpty ? sections : null,
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
            .withValues(alpha: 0.2),
      ),
      child: Center(
        child: AppText(name[0].toUpperCase(), variant: AppTextVariant.body),
      ),
    );
  }
}
