import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/select/app_select.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Demo page section for showcasing select/dropdown variants.
class SelectDemo extends HookConsumerWidget {
  const SelectDemo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = CustomTheme.of(context);
    final fruit = useState<String?>(null);
    final color = useState<String?>(null);
    final size = useState<String?>(null);
    final number = useState<String?>('One');

    return ListView(
      padding: EdgeInsets.all(custom.spacing.lg),
      children: [
        // Basic
        _sectionHeader(context, '基本选择器 (Basic Select)', custom),
        const SizedBox(height: 12),
        Wrap(
          spacing: custom.spacing.md,
          runSpacing: custom.spacing.md,
          children: [
            SizedBox(
              width: 200,
              child: AppSelect<String>(
                value: fruit.value,
                placeholder: '选择水果',
                options: const [
                  AppSelectOption(value: '苹果', label: '苹果', icon: 'star'),
                  AppSelectOption(value: '香蕉', label: '香蕉'),
                  AppSelectOption(value: '橘子', label: '橘子'),
                  AppSelectOption(value: '葡萄', label: '葡萄'),
                ],
                onChanged: (v) => fruit.value = v,
              ),
            ),
            SizedBox(
              width: 200,
              child: AppSelect<String>(
                value: color.value,
                placeholder: '选择颜色',
                options: const [
                  AppSelectOption(value: '红色', label: '红色'),
                  AppSelectOption(value: '绿色', label: '绿色'),
                  AppSelectOption(value: '蓝色', label: '蓝色'),
                  AppSelectOption(value: '黄色', label: '黄色'),
                ],
                onChanged: (v) => color.value = v,
              ),
            ),
          ],
        ),
        if (fruit.value != null || color.value != null)
          Padding(
            padding: EdgeInsets.only(top: custom.spacing.sm),
            child: AppText(
              '已选择: ${fruit.value ?? '-'}, ${color.value ?? '-'}',
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
            ),
          ),
        SizedBox(height: custom.spacing.xl),

        // Disabled
        _sectionHeader(context, '禁用状态 (Disabled)', custom),
        const SizedBox(height: 12),
        SizedBox(
          width: 200,
          child: AppSelect<String>(
            value: size.value,
            placeholder: '尺寸',
            disabled: true,
            options: const [
              AppSelectOption(value: '小', label: '小'),
              AppSelectOption(value: '中', label: '中'),
              AppSelectOption(value: '大', label: '大'),
            ],
            onChanged: (v) => size.value = v,
          ),
        ),
        SizedBox(height: custom.spacing.xl),

        // With initial value
        _sectionHeader(context, '带默认值 (With Default Value)', custom),
        const SizedBox(height: 12),
        SizedBox(
          width: 200,
          child: AppSelect<String>(
            value: number.value,
            placeholder: '数字',
            options: const [
              AppSelectOption(value: 'One', label: '一 (One)'),
              AppSelectOption(value: 'Two', label: '二 (Two)'),
              AppSelectOption(value: 'Three', label: '三 (Three)'),
            ],
            onChanged: (v) => number.value = v,
          ),
        ),
        if (number.value != null)
          Padding(
            padding: EdgeInsets.only(top: custom.spacing.sm),
            child: AppText(
              '已选择: ${number.value}',
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
            ),
          ),
        SizedBox(height: custom.spacing.xl),

        // With label & error
        _sectionHeader(context, '带标签和错误 (With Label & Error)', custom),
        const SizedBox(height: 12),
        SizedBox(
          width: 200,
          child: AppSelect<String>(
            value: null,
            label: '必填字段',
            placeholder: '请选择',
            errorText: '请选择一个选项',
            options: const [
              AppSelectOption(value: 'A', label: '选项 A'),
              AppSelectOption(value: 'B', label: '选项 B'),
              AppSelectOption(value: 'C', label: '选项 C'),
            ],
            onChanged: (v) {},
          ),
        ),
        SizedBox(height: custom.spacing.xl),

        // Size variants
        _sectionHeader(context, '尺寸变体 (Size Variants)', custom),
        const SizedBox(height: 12),
        Wrap(
          spacing: custom.spacing.md,
          runSpacing: custom.spacing.md,
          children: [
            SizedBox(
              width: 160,
              child: AppSelect<String>(
                value: null,
                placeholder: '小尺寸',
                size: FieldSize.sm,
                options: const [
                  AppSelectOption(value: '1', label: '选项 1'),
                  AppSelectOption(value: '2', label: '选项 2'),
                ],
                onChanged: (v) {},
              ),
            ),
            SizedBox(
              width: 160,
              child: AppSelect<String>(
                value: null,
                placeholder: '中尺寸',
                size: FieldSize.md,
                options: const [
                  AppSelectOption(value: '1', label: '选项 1'),
                  AppSelectOption(value: '2', label: '选项 2'),
                ],
                onChanged: (v) {},
              ),
            ),
            SizedBox(
              width: 160,
              child: AppSelect<String>(
                value: null,
                placeholder: '大尺寸',
                size: FieldSize.lg,
                options: const [
                  AppSelectOption(value: '1', label: '选项 1'),
                  AppSelectOption(value: '2', label: '选项 2'),
                ],
                onChanged: (v) {},
              ),
            ),
          ],
        ),

        // Disabled options
        SizedBox(height: custom.spacing.xl),
        _sectionHeader(context, '禁用选项 (Disabled Options)', custom),
        const SizedBox(height: 12),
        SizedBox(
          width: 200,
          child: AppSelect<String>(
            value: null,
            placeholder: '选择项目',
            options: const [
              AppSelectOption(value: 'a', label: '可用项目'),
              AppSelectOption(value: 'b', label: '已禁用项目', enabled: false),
              AppSelectOption(value: 'c', label: '另一个可用项'),
            ],
            onChanged: (v) {},
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    String label,
    CustomTheme custom,
  ) {
    return AppText(
      label,
      variant: AppTextVariant.caption,
      color: custom.colors.textSecondary,
      style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
    );
  }
}
