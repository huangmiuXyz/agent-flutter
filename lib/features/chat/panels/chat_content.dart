import 'package:flutter/material.dart';

import 'package:agent/features/chat/chat_input.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/divider/app_divider.dart';

/// 聊天内容区 — 消息列表 + 输入框
class ChatContent extends StatelessWidget {
  const ChatContent({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Column(
      children: [
        Expanded(child: ColoredBox(color: custom.colors.panelElevated)),
        AppDivider(extent: 1, thickness: 1, color: custom.colors.border),
        const ChatInput(),
      ],
    );
  }
}
