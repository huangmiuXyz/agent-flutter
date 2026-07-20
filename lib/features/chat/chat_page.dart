import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/features/chat/chat_input.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/divider/app_divider.dart';

class ChatDemo extends HookConsumerWidget {
  const ChatDemo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
