import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/select/app_multi_select.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/text/app_text.dart';

class MultiSelectDemo extends HookWidget {
  const MultiSelectDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final selected = useState(<String>{});
    final selectedLarge = useState(<String>{});

    final options = useMemoized(
      () => [
        AppMultiSelectOption(
          value: 'filesystem',
          label: 'Filesystem',
          icon: 'folder',
        ),
        AppMultiSelectOption(value: 'git', label: 'Git', icon: 'layers'),
        AppMultiSelectOption(
          value: 'playwright',
          label: 'Playwright',
          icon: 'cpu',
        ),
        AppMultiSelectOption(
          value: 'memory',
          label: 'Memory',
          icon: 'hardDrive',
        ),
        AppMultiSelectOption(value: 'slack', label: 'Slack', icon: 'mail'),
      ],
    );

    final manyOptions = useMemoized(
      () => List.generate(
        20,
        (i) => AppMultiSelectOption(
          value: 'option_$i',
          label: '选项 $i',
          icon: i.isEven ? 'checkSquare2' : 'square',
        ),
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(custom.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText('AppMultiSelect 示例', variant: AppTextVariant.h2),
          SizedBox(height: custom.spacing.md),

          // ── 默认大小 ──
          AppText('默认大小（FieldSize.md）', variant: AppTextVariant.subtitle),
          SizedBox(height: custom.spacing.sm),
          SizedBox(
            width: 320,
            child: AppMultiSelect<String>(
              label: 'MCP 服务器',
              placeholder: '请选择 MCP 服务器',
              options: options,
              value: selected.value,
              onChanged: (v) => selected.value = v,
            ),
          ),
          SizedBox(height: custom.spacing.lg),

          // ── 已选项显示 ──
          AppText(
            '已选: ${selected.value.isEmpty ? "（无）" : selected.value.join(", ")}',
            variant: AppTextVariant.body,
          ),
          SizedBox(height: custom.spacing.lg),

          // ── 小尺寸 ──
          AppText('小尺寸（FieldSize.sm）', variant: AppTextVariant.subtitle),
          SizedBox(height: custom.spacing.sm),
          SizedBox(
            width: 320,
            child: AppMultiSelect<String>(
              label: '标签',
              placeholder: '选择...',
              size: FieldSize.sm,
              options: options,
              value: selectedLarge.value,
              onChanged: (v) => selectedLarge.value = v,
            ),
          ),
          SizedBox(height: custom.spacing.lg),

          // ── 禁用状态 ──
          AppText('禁用状态', variant: AppTextVariant.subtitle),
          SizedBox(height: custom.spacing.sm),
          SizedBox(
            width: 320,
            child: AppMultiSelect<String>(
              label: '已禁用',
              placeholder: '无法选择',
              disabled: true,
              options: options,
              value: {'filesystem'},
              onChanged: null,
            ),
          ),
          SizedBox(height: custom.spacing.lg),

          // ── 错误状态 ──
          AppText('错误状态', variant: AppTextVariant.subtitle),
          SizedBox(height: custom.spacing.sm),
          SizedBox(
            width: 320,
            child: AppMultiSelect<String>(
              label: '配置',
              placeholder: '请选择',
              errorText: '至少选择一项',
              options: options,
              value: {},
              onChanged: (_) {},
            ),
          ),
          SizedBox(height: custom.spacing.lg),

          // ── 大量选项 ──
          AppText('大量选项（20项）', variant: AppTextVariant.subtitle),
          SizedBox(height: custom.spacing.sm),
          SizedBox(
            width: 320,
            child: AppMultiSelect<String>(
              label: '选项列表',
              placeholder: '请选择...',
              options: manyOptions,
              value: {'option_0', 'option_2', 'option_4'},
              onChanged: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}
