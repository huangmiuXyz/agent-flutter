/// Model list page — shows all models for a provider with enable/disable switches.
///
/// 刷新行为（挂载时从 API 拉取模型列表）：
/// - 配置 `available_models` 中的模型默认**保留**（UI 手动添加 / 手改 JSON / 旧数据
///   均无标记，一律视为用户显式配置，刷新不删）
/// - 仅带 `from_api: true` 标记的模型（UI 里从 API 列表激活的）**跟随远端**：
///   远端不再返回时自动从已激活移除（激活状态清除并写回配置）
/// - 未激活分组 = 远端列表 − 已激活（远端新增的模型出现于此，可手动开启）
///
/// Persists enabled models to config.json via [ConfigFileStore]:
///   language_models.{protocol}.{provider.id}.available_models
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/features/settings/models/provider_info.dart';
import 'package:agent/rust_bridge/api/providers.dart' as api;
import 'package:agent/store/config_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/list/app_big_list.dart';
import 'package:agent/widgets/switch/app_switch.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 模型条目标记：'from_api' = 从 API 列表激活（跟随远端删除）；
/// '' = 无标记（UI 手动添加 / 手改 JSON / 旧数据，刷新一律保留）。
typedef ModelFlags = Map<String, String>;

/// Full-screen model management page for a single provider.
class ModelListPage extends HookWidget {
  final ProviderInfo provider;

  /// Called when the user wants to go back to the config page.
  final VoidCallback onBack;

  const ModelListPage({
    super.key,
    required this.provider,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final searchQuery = useState('');
    // 已激活模型 → 标记（key 即已激活集合）
    final flags = useState<ModelFlags>({});
    // API 拉取的完整模型列表（决定未激活候选 + from_api 模型的去留）
    final modelsList = useState<List<String>>([]);
    final loadingState = useState(true);
    final errorMsg = useState<String?>(null);
    final newModelCtrl = useTextEditingController();
    // 协议段以 config 实际所在段为准（provider 可能配置在 responses/anthropic 段），
    // 检测不到时回退到按名称推断。写错段会导致开关状态无法持久化。
    final protocol =
        protocolFromConfig(ConfigStore.instance.data.value, provider.name) ??
        protocolForProvider(provider.name);

    // ── 写回配置（开关切换 / 追加 / 刷新移除共用）──
    Future<void> writeModels(ModelFlags updated) async {
      try {
        ConfigStore.instance.mutate((m) {
          final languageModels =
              m.putIfAbsent('language_models', () => <String, dynamic>{})
                  as Map<String, dynamic>;
          final protocolConfig =
              languageModels.putIfAbsent(protocol, () => <String, dynamic>{})
                  as Map<String, dynamic>;
          final section =
              protocolConfig.putIfAbsent(
                    provider.name,
                    () => <String, dynamic>{},
                  )
                  as Map<String, dynamic>;
          section['available_models'] = [
            for (final entry in updated.entries)
              if (entry.value == 'from_api')
                {'name': entry.key, 'from_api': true}
              else
                {'name': entry.key},
          ];
        });
        flags.value = updated;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: AppText('操作失败: $e')));
        }
      }
    }

    // ── Load models + enabled state on mount ──
    useEffect(() {
      Future<void> load() async {
        loadingState.value = true;
        errorMsg.value = null;
        try {
          final models = await api.listModels(
            provider: provider.name,
            configPath: ConfigStore.instance.configPath,
          );

          // 读取配置 available_models：无标记的（UI 手动添加 / 手改 JSON / 旧数据）
          // 保留；from_api 仅在远端仍返回时保留
          final rawList =
              (ConfigStore.instance.data.value['language_models']
                      as Map<String, dynamic>?)?[protocol]?[provider
                      .name]?['available_models']
                  as List<dynamic>?;
          final loaded = <String, String>{};
          if (rawList != null) {
            for (final e in rawList) {
              final name = e is Map ? e['name'] : e;
              if (name is! String || name.isEmpty) continue;
              loaded[name] = (e is Map && e['from_api'] == true)
                  ? 'from_api'
                  : '';
            }
          }

          // 移除：from_api 且远端不再返回（跟随远端删除，写回配置）
          final removed = loaded.entries
              .where((e) => e.value == 'from_api' && !models.contains(e.key))
              .map((e) => e.key)
              .toList();
          if (removed.isNotEmpty) {
            for (final r in removed) {
              loaded.remove(r);
            }
            await writeModels(loaded);
          }

          modelsList.value = models;
          flags.value = loaded;
          loadingState.value = false;
        } catch (e) {
          errorMsg.value = e.toString();
          loadingState.value = false;
        }
      }

      load();
      return null;
    }, [provider.name]);

    // ── Toggle handler（开启 = 从 API 列表激活，标记 from_api；关掉 = 删除）──
    Future<void> handleToggle(String model, bool enabled) async {
      final updated = Map<String, String>.from(flags.value);
      if (enabled) {
        // 已有条目（如手动添加的无标记模型）保持原样，否则标记 from_api
        updated.putIfAbsent(model, () => 'from_api');
      } else {
        updated.remove(model);
      }
      await writeModels(updated);
    }

    // ── 手动追加模型（无标记：刷新时与手改 JSON 一样一律保留）──
    Future<void> handleAdd() async {
      final name = newModelCtrl.text.trim();
      if (name.isEmpty) return;
      newModelCtrl.clear();
      final updated = Map<String, String>.from(flags.value)..[name] = '';
      await writeModels(updated);
    }

    // ── Search filter ──
    final query = searchQuery.value.trim().toLowerCase();
    bool matches(String model) {
      if (query.isEmpty) return true;
      return model.toLowerCase().contains(query);
    }

    // 已激活 = 配置集合（刷新后保留）；未激活 = 远端列表 − 已激活
    final active = flags.value.keys.where((m) => matches(m)).toList()..sort();
    final inactive =
        modelsList.value
            .where((m) => !flags.value.containsKey(m) && matches(m))
            .toList()
          ..sort();
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
              AppBreadcrumbItem('设置', onTap: () {}),
              AppBreadcrumbItem('提供商', onTap: onBack),
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
                  // 头部右侧：手动追加模型
                  actions: [
                    SizedBox(
                      width: 220,
                      child: AppField(
                        controller: newModelCtrl,
                        placeholder: '输入模型名',
                        size: FieldSize.sm,
                        onSubmitted: (_) => handleAdd(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppSecondaryButton(
                      text: '添加模型',
                      size: ButtonSize.sm,
                      onPressed: handleAdd,
                    ),
                  ],
                  emptyState: AppBigEmpty(
                    icon: 'search',
                    title: query.isEmpty ? '暂无可用模型' : '没有匹配的模型',
                    hint: query.isEmpty ? '在右上角输入模型名并点击「添加模型」' : '试试其他关键词',
                  ),
                  children: groups,
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
