/// 技能详情页 — 展示技能元信息和 SKILL.md 正文。
///
/// 结构和 [McpDetailPage] 一致：
/// - breadcrumb: 设置 > 技能 > [skill.name]
/// - 来源 / 作用域 / 路径 等元信息
/// - 启用/禁用开关
/// - SKILL.md 正文预览
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/features/skills/models/skill_info.dart';
import 'package:agent/rust_bridge/api/skills.dart' as bridge;
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/markdown/markdown_preview.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 技能详情页。
class SkillDetailPage extends HookWidget {
  final SkillInfo skill;
  final VoidCallback onBack;

  const SkillDetailPage({super.key, required this.skill, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final content = useState<String?>(skill.content.isNotEmpty ? skill.content : null);
    final loading = useState(false);

    // ── 进页面时从 Rust 加载 SKILL.md 正文 ──
    useEffect(() {
      if (content.value != null) return null;
      loading.value = true;
      bridge.loadSkillContent(directoryPath: skill.directoryPath).then((c) {
        content.value = c;
        loading.value = false;
      }).catchError((_) {
        content.value = '(加载失败)';
        loading.value = false;
      });
      return null;
    }, [skill.directoryPath]);

    return ContentFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 面包屑 ──
          AppBreadcrumb(
            items: [
              AppBreadcrumbItem('设置', onTap: () {}),
              AppBreadcrumbItem('技能', onTap: () {}),
              AppBreadcrumbItem(skill.name, onTap: onBack),
              AppBreadcrumbItem('详情'),
            ],
          ),
          SizedBox(height: custom.spacing.lg),

          // ── 元信息 ──
          _MetaRow(label: '名称', value: skill.name),
          _MetaRow(label: '描述', value: skill.description),
          _MetaRow(label: '来源', value: skill.source.name),
          _MetaRow(
            label: '范围',
            value: skill.scope == 'global' ? '全局' : '项目',
          ),
          _MetaRow(label: '路径', value: skill.directoryPath),
          SizedBox(height: custom.spacing.md),

          // ── 分隔 ──
          Divider(height: 1, color: custom.colors.separator),
          SizedBox(height: custom.spacing.md),

          // ── 内容标题 ──
          AppText(
            'SKILL.md',
            variant: AppTextVariant.subtitle,
          ),
          SizedBox(height: custom.spacing.sm),

          // ── SKILL.md 正文预览 ──
          // 在外层 SingleChildScrollView（ContentFrame）中不能使用 Expanded，
          // 改用 ConstrainedBox 确保预览区至少有可见高度。
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: 200),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(custom.spacing.md),
              decoration: BoxDecoration(
                color: custom.colors.cardBackground,
                borderRadius: custom.radii.sm,
                border: Border.all(color: custom.colors.cardBorder),
              ),
              child: loading.value
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : MarkdownPreview(
                text: (content.value?.isNotEmpty == true ? content.value! : '(空)'),
                textStyle: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: custom.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: AppText(
              label,
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
            ),
          ),
          Expanded(
            child: AppText(value, variant: AppTextVariant.body),
          ),
        ],
      ),
    );
  }
}
