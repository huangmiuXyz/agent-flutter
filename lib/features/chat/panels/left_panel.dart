import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 左侧面板 — 会话列表
///
/// TODO: 替换为真实的 SessionList 组件
class LeftPanel extends StatelessWidget {
  const LeftPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Container(
      color: custom.colors.panel,
      child: Column(
        children: [
          // TODO: TBD area above session list
          Expanded(
            child: Center(
              child: AppText(
                '会话列表',
                variant: AppTextVariant.caption,
                color: custom.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
