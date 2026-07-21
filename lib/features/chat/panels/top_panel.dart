import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 顶部面板 — TBD
///
/// TODO: 替换为实际组件（如工具栏、标签栏等）
class TopPanel extends StatelessWidget {
  const TopPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Container(
      height: custom.controls.mediumHeight,
      color: custom.colors.panel,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: custom.spacing.sm),
      child: AppText(
        '顶部面板',
        variant: AppTextVariant.caption,
        color: custom.colors.textSecondary,
      ),
    );
  }
}
