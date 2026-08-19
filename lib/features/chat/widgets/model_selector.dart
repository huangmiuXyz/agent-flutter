import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/agents/store/agent_store.dart';
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
    // 当前智能体（切换时同步刷新下方 resolveModel 的结果）
    useExistingSignal(AgentStore.instance.currentAgent);
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
            // 选中后按钮上显示「提供商/模型名」；下拉菜单项仍只显示模型名（按提供商分组）
            'displayLabel': '${p.key}/$name',
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

    // 当前选中项用「真正生效」的 (provider, model) 复合值匹配：
    // 非全局智能体有自己的 default_model 时优先显示智能体的，
    // 否则显示全局配置的 —— 与发送消息时 [AgentStore.resolveModel] 一致，
    // 避免按钮上显示的模型与实际发出的模型不一致。
    final resolved = AgentStore.instance.resolveModel();
    final currentValue =
        resolved.provider.isNotEmpty && resolved.model.isNotEmpty
            ? AppProviderModelSelect.encodeKey(
                resolved.provider,
                resolved.model,
              )
            : null;

    void onModelChanged(dynamic val) {
      if (val is! String) return;
      final decoded = AppProviderModelSelect.decodeKey(val);
      if (decoded == null) return;
      final (provider, model) = decoded;
      // 写入当前生效位置（全局或当前智能体的 config.json）
      AgentStore.instance.setDefaultModel(provider, model).then((ok) {
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: AppText('设置默认模型失败')),
          );
        }
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
      // 选中后按钮显示「提供商/模型名」，限制宽度避免超长撑开工具栏
      maxWidth: 220,
      // 面板顶部搜索：同时匹配模型名与提供商名
      searchable: true,
      searchHint: '搜索提供商 / 模型',
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
