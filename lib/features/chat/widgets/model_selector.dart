import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/services/config_service.dart';
import 'package:agent/services/llm/llm_providers.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/select/panel_selector.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 模型选择器 — 从 config.json 读取已激活的模型，按提供商分组展示
class ModelSelector extends HookConsumerWidget {
  const ModelSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentModel = ref.watch(currentModelProvider);

    // 从 config.json 读取所有已激活的模型
    final store = ref.read(configFileStoreProvider);
    final allData = store.readAll();
    final languageModels = allData['language_models'] as Map<String, dynamic>?;

    // model 名 → 提供商名的映射
    final modelToProvider = <String, String>{};
    List<dynamic> items = [];
    if (languageModels != null) {
      for (final protocolEntry in languageModels.entries) {
        final providers = protocolEntry.value as Map<String, dynamic>?;
        if (providers == null) continue;
        for (final providerEntry in providers.entries) {
          final providerName = providerEntry.key;
          final providerConfig = providerEntry.value as Map<String, dynamic>?;
          if (providerConfig == null) continue;
          final raw = providerConfig['available_models'];
          if (raw == null) continue;
          try {
            final decoded = jsonDecode(jsonEncode(raw));
            if (decoded is List) {
              for (final e in decoded) {
                final name = e is Map ? e['name'] as String? : e as String?;
                if (name != null) {
                  modelToProvider[name] = providerName;
                  items.add(e);
                }
              }
            }
          } catch (_) {}
        }
      }
    }

    final currentValue = currentModel.isNotEmpty ? currentModel : null;

    void onModelChanged(dynamic val) {
      if (val == null) return;
      String? name;
      if (val is Map) {
        name = val['name'] as String?;
      } else if (val is String) {
        name = val;
      }
      if (name == null || name.isEmpty) return;

      // 设置模型和提供商
      ref.read(currentModelProvider.notifier).select(name);
      final provider = modelToProvider[name];
      if (provider != null && provider.isNotEmpty) {
        ref.read(currentProviderProvider.notifier).select(provider);
        ref.read(defaultModelProvider.notifier).setDefault(provider, name);
      }
    }

    if (items.isEmpty) {
      return _buildPlaceholder(context, '未选择模型');
    }

    return PanelSelector<String>(
      value: currentValue,
      placeholder: '选择模型',
      data: items,
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
