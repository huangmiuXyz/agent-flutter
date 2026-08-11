/// 推理强度选择器 — 显示在聊天输入框工具栏左侧（图片上传按钮旁）。
///
/// 提供从「无」到「最大」的标准化等级（见 [kReasoningEffortValues]），
/// 与 [ModelSelector] 使用相同的 [PanelSelector] 组件。
///
/// 选中结果持久化到当前生效配置（全局或当前智能体的 config.json）中
/// 对应模型的 `reasoning_effort` 字段（模型级优先，回退 provider 级），
/// 后端发送请求时按 (provider, model) 读取生效：
/// - provider-default：在模型条目上写入 `provider-default`（覆盖 provider 级配置，
///   省略参数，使用该模型提供商的默认推理行为）
/// - none：禁用推理
/// - minimal / low / medium / high / xhigh：由弱到强的推理强度
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/agents/store/agent_store.dart';
import 'package:agent/features/settings/models/provider_info.dart';
import 'package:agent/store/config_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/select/panel_selector.dart';
import 'package:agent/widgets/text/app_text.dart';

class ReasoningSelector extends HookWidget {
  const ReasoningSelector({super.key});

  @override
  Widget build(BuildContext context) {
    // 当前智能体（切换时同步刷新下方 resolveReasoningEffort 的结果）
    useExistingSignal(AgentStore.instance.currentAgent);
    // 监听 ConfigStore.data 变化，确保列表在跨窗口同步后刷新
    useExistingSignal(ConfigStore.instance.data);

    final items = <dynamic>[
      for (final v in kReasoningEffortValues)
        {'label': kReasoningEffortLabels[v], 'value': v},
    ];

    // 未配置模型时无 provider 可写，退化为占位文本
    final resolved = AgentStore.instance.resolveModel();
    if (resolved.provider.isEmpty || resolved.model.isEmpty) {
      return _buildPlaceholder(context);
    }

    final currentValue = AgentStore.instance.resolveReasoningEffort();

    return PanelSelector<String>(
      value: currentValue,
      placeholder: kReasoningEffortLabels[kReasoningEffortProviderDefault],
      // 按钮以灯泡图标代替「推理:」文字前缀
      buttonIcon: 'lightbulb',
      data: items,
      // 标签为简短英文，菜单宽度收窄；按钮不设限宽，避免文本被截断成省略号
      menuMinWidth: 100,
      onChanged: (v) {
        AgentStore.instance.setReasoningEffort(v).then((ok) {
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: AppText('设置推理强度失败：找不到当前提供商的配置')),
            );
          }
        });
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(
          'lightbulb',
          size: custom.typography.captionSize,
          color: custom.colors.textSecondary,
        ),
        SizedBox(width: custom.spacing.xs),
        AppText(
          kReasoningEffortLabels[kReasoningEffortProviderDefault]!,
          variant: AppTextVariant.caption,
          color: custom.colors.textSecondary,
        ),
      ],
    );
  }
}
