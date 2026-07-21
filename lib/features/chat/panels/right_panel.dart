import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 右侧面板 — TBD
///
/// TODO: 替换为实际组件
class RightPanel extends StatelessWidget {
  const RightPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Container(
      color: custom.colors.panel,
      child: Center(
        child: AppText(
          '右侧面板',
          variant: AppTextVariant.caption,
          color: custom.colors.textSecondary,
        ),
      ),
    );
  }
}
