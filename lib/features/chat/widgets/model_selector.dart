import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/settings/models/provider_info.dart';
import 'package:agent/features/settings/settings_page.dart';
import 'package:agent/layout/main_layout.dart' show showSettingsDialog;
import 'package:agent/store/config_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/select/app_provider_model_select.dart';
import 'package:agent/widgets/select/panel_selector.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 模型选择器 — 从 config.json 读取已激活的模型，按提供商分组展示
class ModelSelector extends HookWidget {
  const ModelSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final currentProvider =
        useExistingSignal(ConfigStore.instance.currentProvider);
    final currentModel = useExistingSignal(ConfigStore.instance.currentModel);
    // 监听 ConfigStore.data 变化，确保列表在跨窗口同步后刷新
    useExistingSignal(ConfigStore.instance.data);

    // 从 config.json 读取所有已激活的模型
    final allData = ConfigStore.instance.data.value;
    final providerModels = parseProviderModels(allData);

    final items = <dynamic>[
      for (final p in providerModels.entries)
        for (final name in p.value)
          {
            'name': name,
            // 选项值携带 (provider, model)，允许同名模型出现在多个提供商分组
            'value': AppProviderModelSelect.encodeKey(p.key, name),
            'group': p.key,
            // 悬停齿轮：直达该模型所属提供商的配置页（不改变当前选中）
            'hoverIcon': 'settings',
            'onHoverTap': () {
              showSettingsDialog(
                context,
                tab: SettingsTab.models,
                provider: ProviderInfo(name: p.key),
              );
            },
          },
    ];

    // 当前选中项同样用 (provider, model) 复合值匹配，
    // 避免同名模型在不同提供商下同时被打勾/显示错乱
    final currentValue =
        currentProvider.value.isNotEmpty && currentModel.value.isNotEmpty
            ? AppProviderModelSelect.encodeKey(
                currentProvider.value,
                currentModel.value,
              )
            : null;

    void onModelChanged(dynamic val) {
      if (val is! String) return;
      final decoded = AppProviderModelSelect.decodeKey(val);
      if (decoded == null) return;
      final (provider, model) = decoded;
      ConfigStore.instance.mutate((m) {
        m['default_model'] = {'provider': provider, 'model': model};
      });
    }

    if (items.isEmpty) {
      return _buildPlaceholder(context, '未选择模型');
    }

    return PanelSelector<String>(
      value: currentValue,
      placeholder: '选择模型',
      data: items,
      menuMaxWidth: custom.controls.contextMenuMaxWidth,
      onChanged: onModelChanged,
    );
  }

  Widget _buildPlaceholder(BuildContext context, String text) {
    final custom = CustomTheme.of(context);
    return AppText(
      text,
      variant: AppTextVariant.caption,
      color: custom.colors.textSecondary,
    );
  }
}
