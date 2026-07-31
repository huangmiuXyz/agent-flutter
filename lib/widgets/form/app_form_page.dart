/// 设置页统一表单脚手架。
///
/// 所有设置表单页共用同一个外壳：面包屑、标题区（h2 + 副标题）、
/// 字段间距、宽度、底部按钮栏排布全部由 [AppFormPage] 内部约束，
/// 页面代码通过插槽（breadcrumbItems / title / subtitle / children /
/// actions）注入内容，不再手写布局样板。
library;

import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 表单内容宽度 —— 所有设置表单页统一收窄到该宽度。
const double kFormPageWidth = 560;

/// 设置页表单脚手架。
class AppFormPage extends StatelessWidget {
  /// 插槽：面包屑导航。
  final List<AppBreadcrumbItem> breadcrumbItems;

  /// 插槽：页面标题（h2 变体）。
  final String title;

  /// 插槽：标题下方的说明文字（caption 变体）。
  final String? subtitle;

  /// 插槽：标题行右侧的扩展区域（如搜索框、筛选）。
  final Widget? titleTrailing;

  /// 插槽：表单主体。字段之间的间距由脚手架自动插入（`spacing.md`）。
  final List<Widget> children;

  /// 插槽：底部操作栏，见 [FormActions]。
  final FormActions? actions;

  /// 是否允许整页滚动，默认 `true`。
  final bool scrollable;

  const AppFormPage({
    super.key,
    required this.breadcrumbItems,
    required this.title,
    this.subtitle,
    this.titleTrailing,
    this.children = const [],
    this.actions,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return ContentFrame(
      scrollable: scrollable,
      child: SizedBox(
        width: kFormPageWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppBreadcrumb(items: breadcrumbItems),
            SizedBox(height: custom.spacing.lg),
            _buildHeader(custom),
            SizedBox(height: custom.spacing.lg + 4),
            ..._buildBody(custom),
            if (actions != null) ...[
              SizedBox(height: custom.spacing.lg + 4),
              actions!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(CustomTheme custom) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(title, variant: AppTextVariant.h2),
              if (subtitle != null) ...[
                SizedBox(height: custom.spacing.xs),
                AppText(
                  subtitle!,
                  variant: AppTextVariant.caption,
                  color: custom.colors.textSecondary,
                ),
              ],
            ],
          ),
        ),
        if (titleTrailing != null) ?titleTrailing,
      ],
    );
  }

  List<Widget> _buildBody(CustomTheme custom) {
    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        result.add(SizedBox(height: custom.spacing.md));
      }
      result.add(children[i]);
    }
    return result;
  }
}

/// 表单底部操作栏。
///
/// 统一排布规则：主操作（保存/添加）靠左，次要操作（删除/管理/取消）
/// 靠右，次要操作之间使用 `spacing.sm`。按钮尺寸由调用方决定，
/// 默认统一使用 `ButtonSize.md`。
class FormActions extends StatelessWidget {
  /// 主操作按钮，靠左排列。
  final List<Widget> primary;

  /// 次要操作按钮，靠右排列。
  final List<Widget> secondary;

  const FormActions({
    super.key,
    this.primary = const [],
    this.secondary = const [],
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return Row(
      children: [
        ...primary,
        if (secondary.isNotEmpty) const Spacer(),
        for (var i = 0; i < secondary.length; i++) ...[
          if (i > 0) SizedBox(width: custom.spacing.sm),
          secondary[i],
        ],
      ],
    );
  }
}
