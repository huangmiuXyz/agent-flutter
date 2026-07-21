import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agent/features/chat/chat_fleather.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/utils/layout_utils.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';

class ChatInput extends ConsumerWidget {
  const ChatInput({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = CustomTheme.of(context);
    final physicalHeight = 130.0 / MediaQuery.of(context).devicePixelRatio;
    final readingWidth = ref.watch(readingWidthProvider);
    return Padding(
      padding: EdgeInsets.all(custom.spacing.sm),
      child: SizedBox(
        width: readingWidth,
        height: physicalHeight,
        child: Column(
          children: [
            const Expanded(child: ChatFleather()),
            SizedBox(
              height: custom.spacing.lg,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                    AppIconButton(
                      icon: 'arrowUpRight',
                      size: ButtonSize.sm,
                      backgroundColor: custom.colors.hover,
                      onPressed: () {
                        // TODO: Send message
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
