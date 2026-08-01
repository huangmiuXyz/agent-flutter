import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/store/config_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/select/panel_selector.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 模型选择器 — 从 config.json 读取已激活的模型，按提供商分组展示
class ModelSelector extends HookWidget {
  const ModelSelector({super.key});

  /// 编码 (provider, model) 复合键。
  ///
  /// 不同提供商可能提供相同模型 ID，选项值必须同时携带提供商信息，
  /// 否则选中/回显时无法区分具体是哪个提供商的模型。
  static String encodeKey(String provider, String model) =>
      jsonEncode([provider, model]);

  /// 解码 [encodeKey] 生成的复合键，非法输入返回 null。
  static (String, String)? decodeKey(String key) {
    try {
      final decoded = jsonDecode(key);
      if (decoded is List && decoded.length == 2) {
        final provider = decoded[0] as String?;
        final model = decoded[1] as String?;
        if (provider != null && provider.isNotEmpty && model != null) {
          return (provider, model);
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentProvider =
        useExistingSignal(ConfigStore.instance.currentProvider);
    final currentModel = useExistingSignal(ConfigStore.instance.currentModel);
    // 监听 ConfigStore.data 变化，确保列表在跨窗口同步后刷新
    useExistingSignal(ConfigStore.instance.data);

    // 从 config.json 读取所有已激活的模型
    final allData = ConfigStore.instance.data.value;
    final languageModels = allData['language_models'] as Map<String, dynamic>?;

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
                final Map<String, dynamic> entry;
                if (e is Map) {
                  entry = Map<String, dynamic>.from(e);
                } else {
                  entry = {'name': e.toString()};
                }
                final name = entry['name'] as String?;
                if (name != null && name.isNotEmpty) {
                  // 选项值携带 (provider, model)，允许同名模型出现在多个提供商分组
                  entry['value'] = encodeKey(providerName, name);
                  entry['group'] = providerName;
                  items.add(entry);
                }
              }
            }
          } catch (_) {}
        }
      }
    }

    // 当前选中项同样用 (provider, model) 复合值匹配，
    // 避免同名模型在不同提供商下同时被打勾/显示错乱
    final currentValue =
        currentProvider.value.isNotEmpty && currentModel.value.isNotEmpty
            ? encodeKey(currentProvider.value, currentModel.value)
            : null;

    void onModelChanged(dynamic val) {
      if (val is! String) return;
      final decoded = decodeKey(val);
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
