import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/features/chat/chat_fleather.dart';
import 'package:agent/features/chat/widgets/model_selector.dart';
import 'package:agent/services/llm/llm_providers.dart';
import 'package:agent/services/session/session_manager.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/utils/layout_utils.dart';

import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';

class ChatInput extends HookConsumerWidget {
  const ChatInput({super.key, this.fullHeight = false});

  final bool fullHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = CustomTheme.of(context);
    final physicalHeight = 130.0 / MediaQuery.of(context).devicePixelRatio;
    final readingWidth = ref.watch(readingWidthProvider);
    final controller = useMemoized(() => FleatherController());
    final sending = useState(false);

    Future<void> send() async {
      final text = controller.document
          .toPlainText()
          .replaceAll('\n', '')
          .trim();
      if (text.isEmpty) return;

      final provider = ref.read(currentProviderProvider);
      final model = ref.read(currentModelProvider);
      if (provider.isEmpty || model.isEmpty) return;

      sending.value = true;
      controller.clear();

      String sessionId =
          SessionManager.instance.selectedId.value ??
          await SessionManager.instance.createSession(
            service: ref.read(llmServiceProvider),
            dbPath: ref.read(dbPathProvider),
          );

      try {
        await SessionManager.instance.sendMessage(
          sessionId: sessionId,
          provider: provider,
          model: model,
          prompt: text,
          service: ref.read(llmServiceProvider),
          dbPath: ref.read(dbPathProvider),
          configPath: ref.read(configPathProvider),
        );
      } finally {
        sending.value = false;
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        custom.spacing.sm,
        custom.spacing.xs,
        custom.spacing.sm,
        custom.spacing.sm,
      ),
      child: SizedBox(
        width: readingWidth,
        height: fullHeight ? null : physicalHeight,
        child: Column(
          children: [
            Expanded(child: ChatFleather(controller: controller, onSubmit: send)),
            SizedBox(
              height: custom.spacing.lg,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Spacer(),
                  const ModelSelector(),
                  SizedBox(width: custom.spacing.xs),
                  AppIconButton(
                    icon: 'arrowUpRight',
                    size: ButtonSize.sm,
                    backgroundColor: custom.colors.hover,
                    disabled: sending.value,
                    onPressed: send,
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