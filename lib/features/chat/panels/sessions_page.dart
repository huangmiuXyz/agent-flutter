/// 移动端会话列表页 — 底部壳 Tab 1。
///
/// 复用桌面 LeftPanel 内容（会话 / 检查点切换 + 列表），
/// 外层补 AppBar（标题 + 命令面板入口）。
library;

import 'package:flutter/material.dart';

import 'package:agent/features/chat/panels/left_panel.dart';
import 'package:agent/features/commands/widgets/command_palette.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/text/app_text.dart';

class SessionsPage extends StatelessWidget {
  const SessionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: custom.colors.panel,
        surfaceTintColor: Colors.transparent,
        title: const AppText(
          'Agent',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppIconButton(
              icon: 'command',
              size: ButtonSize.sm,
              tooltip: '命令面板',
              onPressed: () => showCommandPalette(context),
            ),
          ),
        ],
      ),
      body: const LeftPanel(),
    );
  }
}
