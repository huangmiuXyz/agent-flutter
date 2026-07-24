/// Model list page — shows all models for a provider with enable/disable switches.
///
/// Persists enabled models to config.json via [ConfigFileStore]:
///   language_models.{protocol}.{provider.id}.available_models
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/features/settings/models/provider_info.dart';
import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/services/config_service.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/list/app_big_list.dart';
import 'package:agent/widgets/switch/app_switch.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Full-screen model management page for a single provider.
class ModelListPage extends HookConsumerWidget {
  final ProviderInfo provider;

  /// Called when the user wants to go back to the config page.
  final VoidCallback onBack;

  const ModelListPage({
    super.key,
    required this.provider,
    required this.onBack,
  });

  /// Map provider name to the protocol used in config.json.
  String _protocolFor(String name) {
    if (name == 'Anthropic') return 'anthropic';
    return 'openai_compatible';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = CustomTheme.of(context);
    final searchQuery = useState('');
    final activeModels = useState<Set<String>>({});
    final modelsList = useState<List<String>>([]);
    final loadingState = useState(true);
    final errorMsg = useState<String?>(null);
    final protocol = _protocolFor(provider.name);

    // ── Load models + enabled state on mount ──
    useEffect(() {
      Future<void> load() async {
        loadingState.value = true;
        errorMsg.value = null;
        try {
          final cfgPath = ref.read(configPathProvider);
          final models = await api.listModels(
            provider: provider.name,
            configPath: cfgPath,
          );

          // Read enabled models from config
          final store = ref.read(configFileStoreProvider);
          final raw = store.readPath(
            'language_models.$protocol.${provider.name}.available_models',
          );
          Set<String> enabled = {};
          if (raw != null) {
            try {
              final decoded = jsonDecode(raw);
              if (decoded is List) {
                enabled = decoded
                    .map((e) => (e is Map ? e['name'] : e) as String)
                    .toSet();
              }
            } catch (_) {}
          }

          modelsList.value = models;
          activeModels.value = enabled;
          loadingState.value = false;
        } catch (e) {
          errorMsg.value = e.toString();
          loadingState.value = false;
        }
      }

      load();
      return null;
    }, [provider.name]);

    // ── Toggle handler ──
    Future<void> handleToggle(String model, bool enabled) async {
      try {
        final store = ref.read(configFileStoreProvider);
        final key =
            'language_models.$protocol.${provider.name}.available_models';

        final updated = Set<String>.from(activeModels.value);
        if (enabled) {
          updated.add(model);
        } else {
          updated.remove(model);
        }

        store.writePath(
          key,
          updated.map((name) => {'name': name}).toList(),
        );
        activeModels.value = updated;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
        }
      }
    }

    // ── Search filter ──
    final query = searchQuery.value.trim().toLowerCase();
    bool matches(String model) {
      if (query.isEmpty) return true;
      return model.toLowerCase().contains(query);
    }

    final active = modelsList.value
        .where((m) => activeModels.value.contains(m) && matches(m))
        .toList();
    final inactive = modelsList.value
        .where((m) => !activeModels.value.contains(m) && matches(m))
        .toList();
    final total = active.length + inactive.length;

    // ── Build groups ──
    final groups = <Widget>[];
    if (active.isNotEmpty) {
      groups.add(
        AppBigGroup(
          label: '已激活',
          children: [
            for (final model in active) _modelRow(model, true, handleToggle),
          ],
        ),
      );
    }
    if (inactive.isNotEmpty) {
      groups.add(
        AppBigGroup(
          label: '未激活',
          children: [
            for (final model in inactive) _modelRow(model, false, handleToggle),
          ],
        ),
      );
    }

    return ContentFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Breadcrumb ----
          AppBreadcrumb(
            items: [
              AppBreadcrumbItem('Settings', onTap: () {}),
              AppBreadcrumbItem('Models', onTap: onBack),
              AppBreadcrumbItem(provider.label, onTap: onBack),
              AppBreadcrumbItem('管理模型'),
            ],
          ),
          SizedBox(height: custom.spacing.lg),

          // ---- Content ----
          loadingState.value
              ? const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              : errorMsg.value != null
              ? Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: AppText('加载失败: ${errorMsg.value}')),
                )
              : AppBigList(
                  count: total,
                  countLabel: '个模型',
                  showSearch: true,
                  searchTerm: searchQuery.value,
                  onSearchChanged: (v) => searchQuery.value = v,
                  searchPlaceholder: '搜索模型...',
                  children: groups,
                  emptyState: AppBigEmpty(
                    icon: 'search',
                    title: query.isEmpty ? '暂无可用模型' : '没有匹配的模型',
                    hint: query.isEmpty ? '' : '试试其他关键词',
                  ),
                ),
        ],
      ),
    );
  }

  Widget _modelRow(
    String model,
    bool enabled,
    Future<void> Function(String, bool) onToggle,
  ) {
    return AppBigRow(
      key: ValueKey('model_$model'),
      name: model,
      description: null,
      dot: false,
      actions: [
        AppSwitch(
          value: enabled,
          onChanged: (v) => onToggle(model, v),
          size: SwitchSize.md,
        ),
      ],
    );
  }
}
