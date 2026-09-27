/// 移动端会话列表页 — 底部壳 Tab 1。
///
/// 复用桌面 LeftPanel 内容（会话 / 检查点切换 + 列表）。
library;

import 'package:flutter/material.dart';

import 'package:agent/features/chat/panels/left_panel.dart';
import 'package:agent/theme/custom_theme.dart';

class SessionsPage extends StatelessWidget {
  const SessionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Scaffold(
      backgroundColor: custom.colors.panel,
      body: const LeftPanel(),
    );
  }
}