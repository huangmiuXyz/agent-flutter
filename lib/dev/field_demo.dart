import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Demo page section for showcasing field input variants.
class FieldDemo extends ConsumerWidget {
  const FieldDemo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = CustomTheme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Size variants
        _sectionHeader(context, '尺寸变体 (Size Variants)', custom),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 200,
              child: AppField(size: FieldSize.sm, placeholder: '小尺寸 (SM)'),
            ),
            SizedBox(
              width: 200,
              child: AppField(size: FieldSize.md, placeholder: '中尺寸 (MD)'),
            ),
            SizedBox(
              width: 200,
              child: AppField(size: FieldSize.lg, placeholder: '大尺寸 (LG)'),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // With icons
        _sectionHeader(context, '带图标 (With Icons)', custom),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 200,
              child: AppField(
                size: FieldSize.sm,
                icon: 'search',
                placeholder: '搜索...',
              ),
            ),
            SizedBox(
              width: 200,
              child: AppField(
                size: FieldSize.md,
                icon: 'search',
                placeholder: '搜索...',
              ),
            ),
            SizedBox(
              width: 200,
              child: AppField(
                size: FieldSize.lg,
                icon: 'search',
                placeholder: '搜索...',
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // With suffix icon
        _sectionHeader(context, '带后缀图标 (With Suffix Icon)', custom),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 200,
              child: AppField(
                size: FieldSize.sm,
                placeholder: '密码',
                suffixIcon: 'eye',
                obscureText: true,
              ),
            ),
            SizedBox(
              width: 200,
              child: AppField(
                size: FieldSize.md,
                placeholder: '密码',
                suffixIcon: 'eye',
                obscureText: true,
              ),
            ),
            SizedBox(
              width: 200,
              child: AppField(
                size: FieldSize.lg,
                placeholder: '密码',
                suffixIcon: 'eye',
                obscureText: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // With label
        _sectionHeader(context, '带标签 (With Label)', custom),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 200,
              child: AppField(
                size: FieldSize.sm,
                label: '用户名',
                icon: 'pencil',
                placeholder: '请输入用户名',
              ),
            ),
            SizedBox(
              width: 200,
              child: AppField(
                size: FieldSize.md,
                label: '用户名',
                icon: 'pencil',
                placeholder: '请输入用户名',
              ),
            ),
            SizedBox(
              width: 200,
              child: AppField(
                size: FieldSize.lg,
                label: '用户名',
                icon: 'pencil',
                placeholder: '请输入用户名',
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // States
        _sectionHeader(context, '状态 (States)', custom),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 200,
              child: const AppField(
                size: FieldSize.md,
                placeholder: '已禁用',
                enabled: false,
              ),
            ),
            SizedBox(
              width: 200,
              child: const AppField(
                size: FieldSize.md,
                placeholder: '错误状态',
                errorText: '输入内容无效',
              ),
            ),
            SizedBox(
              width: 200,
              child: const AppField(
                size: FieldSize.md,
                placeholder: '含图标+错误',
                icon: 'search',
                errorText: '搜索失败',
              ),
            ),
          ],
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
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: custom.colors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}
