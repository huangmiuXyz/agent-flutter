import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/dialog/app_dialog.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Demo page section for showcasing the Dialog component.
class DialogDemo extends HookConsumerWidget {
  const DialogDemo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = CustomTheme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // --- Confirm Dialog ---
        _sectionHeader(context, '确认弹窗 (Confirm Dialog)', custom),
        const SizedBox(height: 12),
        AppPrimaryButton(
          text: '打开确认弹窗',
          onPressed: () => AppDialog.show(
            context: context,
            title: '删除文件',
            child: AppText('确定要删除该文件吗？此操作不可恢复。'),
            onOk: () {},
          ),
        ),
        const SizedBox(height: 32),

        // --- Without Title ---
        _sectionHeader(context, '无标题弹窗 (Without Title)', custom),
        const SizedBox(height: 12),
        AppSecondaryButton(
          text: '打开无标题弹窗',
          onPressed: () => AppDialog.show(
            context: context,
            child: AppText('这是一条没有标题的提示消息。'),
            onOk: () {},
          ),
        ),
        const SizedBox(height: 32),

        // --- Custom Content ---
        _sectionHeader(context, '自定义内容 (Custom Content)', custom),
        const SizedBox(height: 12),
        AppSecondaryButton(
          text: '打开自定义弹窗',
          onPressed: () => AppDialog.show(
            context: context,
            title: '用户信息',
            width: 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _infoRow(custom, '用户名', 'zhangsan'),
                SizedBox(height: custom.spacing.sm),
                _infoRow(custom, '邮箱', 'zhangsan@example.com'),
                SizedBox(height: custom.spacing.sm),
                _infoRow(custom, '角色', '管理员'),
              ],
            ),
            okText: '保存',
            cancelText: '取消',
            onOk: () {},
          ),
        ),
        const SizedBox(height: 32),

        // --- Without Footer ---
        _sectionHeader(context, '无底部按钮 (Without Footer)', custom),
        const SizedBox(height: 12),
        AppSecondaryButton(
          text: '打开无按钮弹窗',
          onPressed: () => AppDialog.show(
            context: context,
            title: '提示',
            child: AppText('这是一个没有底部按钮的弹窗，点击遮罩或关闭按钮关闭。'),
            showFooter: false,
          ),
        ),
        const SizedBox(height: 32),

        // --- Long Content (Scrolling) ---
        _sectionHeader(context, '长内容滚动 (Scrolling Content)', custom),
        const SizedBox(height: 12),
        AppSecondaryButton(
          text: '打开长内容弹窗',
          onPressed: () => AppDialog.show(
            context: context,
            title: '使用条款',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                10,
                (i) => Padding(
                  padding: EdgeInsets.only(bottom: custom.spacing.md),
                  child: AppText(
                    '${i + 1}. 这是条款的第 ${i + 1} 条内容。用户在使用本产品前需仔细阅读并同意所有条款。',
                    variant: AppTextVariant.body,
                    color: custom.colors.textSecondary,
                  ),
                ),
              ),
            ),
            okText: '同意',
            onOk: () {},
          ),
        ),
      ],
    );
  }

  Widget _infoRow(CustomTheme custom, String label, String value) {
    return Row(
      children: [
        AppText(
          label,
          variant: AppTextVariant.body,
          color: custom.colors.textSecondary,
        ),
        SizedBox(width: custom.spacing.md),
        AppText(value, variant: AppTextVariant.body),
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
