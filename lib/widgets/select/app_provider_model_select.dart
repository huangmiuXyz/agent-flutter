/// 表单用模型选择器 — 从全局 config.json 读取已激活的模型，按提供商分组展示。
///
/// 与聊天页 [ModelSelector] 使用相同的分组数据与 (provider, model) 复合键，
/// 但渲染样式与表单其他 select 一致（[AppSelect] 输入框风格）。
/// 表单里选择模型的地方统一使用本组件。
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/settings/models/provider_info.dart';
import 'package:agent/store/config_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/select/app_select.dart';

/// 表单用模型选择器（[AppSelect] 样式 + 提供商分组）。
class AppProviderModelSelect extends HookWidget {
  /// 表单 label（如「默认模型」）。
  final String? label;

  /// 未选择时显示的提示文本。
  final String? placeholder;

  /// 当前值：[encodeKey] 生成的复合键；null = 未选择。
  final String? value;

  /// 是否显示「（不设置）」项（清除选择，用于可选字段）。默认 false。
  final bool allowClear;

  /// 选中回调：复合键；选择「（不设置）」时回传空串。
  final ValueChanged<String?>? onChanged;

  const AppProviderModelSelect({
    super.key,
    this.label,
    this.placeholder,
    this.value,
    this.allowClear = false,
    this.onChanged,
  });

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
    final custom = CustomTheme.of(context);
    // 监听全局配置变化，确保选项在跨窗口同步后刷新
    useExistingSignal(ConfigStore.instance.data);
    final allData = ConfigStore.instance.data.value;
    final providerModels = parseProviderModels(allData);

    final options = <AppSelectOption<String>>[
      if (allowClear) const AppSelectOption(value: '', label: '（不设置）'),
      for (final p in providerModels.entries)
        for (final m in p.value)
          AppSelectOption<String>(
            value: encodeKey(p.key, m),
            label: m,
            group: p.key,
          ),
    ];

    return AppSelect<String>(
      label: label,
      placeholder: placeholder,
      value: value,
      options: options,
      menuMaxWidth: custom.controls.contextMenuMaxWidth,
      onChanged: onChanged,
    );
  }
}
