/// 移动端聊天页 — 全屏路由 `/chat/:sessionId`（覆盖底部壳，带返回）。
///
/// AppBar：返回 + 会话标题 + 命令面板入口；
/// 内容复用 ChatPage 的移动分支（消息 + 输入单栏）。
library;

import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:agent/features/chat/chat_page.dart';
import 'package:agent/features/commands/widgets/command_palette.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/text/app_text.dart';

class ChatRoutePage extends StatelessWidget {
  final String sessionId;

  const ChatRoutePage({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: custom.colors.panel,
        surfaceTintColor: Colors.transparent,
        title: SignalBuilder(
          builder: (_) {
            final session = SessionStore.instance.sessionList.value
                .where((s) => s.id == sessionId)
                .firstOrNull;
            return AppText(
              session?.name ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            );
          },
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
      body: const ChatPage(),
    );
  }
}
