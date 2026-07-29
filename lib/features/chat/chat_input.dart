import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:signals_flutter/signals_flutter.dart';

import 'package:agent/features/agents/store/agent_store.dart';
import 'package:agent/features/agents/widgets/agent_selector.dart';
import 'package:agent/features/chat/widgets/model_selector.dart';
import 'package:agent/features/chat/chat_fleather.dart';
import 'package:agent/store/message_queue_store.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/utils/layout_utils.dart' show readingWidth;

import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';

class ChatInput extends HookWidget {
  const ChatInput({super.key, this.fullHeight = false});

  final bool fullHeight;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final physicalHeight = 130.0 / MediaQuery.of(context).devicePixelRatio;
    final width = readingWidth;
    final controller = useMemoized(() => FleatherController());
    final sending = useState(false);

    Future<void> send() async {
      final text = controller.document
          .toPlainText()
          .replaceAll('\n', '')
          .trim();
      if (text.isEmpty) return;

      final sid = SessionStore.instance.selectedId.value;
      final isStreaming =
          sid != null &&
          SessionStore.instance.streamingSessionIds.value.contains(sid);

      if (isStreaming) {
        // 流式输出中 → 入队，等待当前回复结束后自动发送
        MessageQueueStore.instance.enqueue(text);
        controller.clear();
        MessageQueueStore.instance.expand();
        return;
      }

      final resolved = AgentStore.instance.resolveModel();
      final provider = resolved.provider;
      final model = resolved.model;
      if (provider.isEmpty || model.isEmpty) return;

      sending.value = true;
      controller.clear();

      String sessionId = sid ?? await SessionStore.instance.createSession();

      try {
        await SessionStore.instance.sendMessage(
          sessionId: sessionId,
          provider: provider,
          model: model,
          prompt: text,
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
        width: width,
        height: fullHeight ? null : physicalHeight,
        child: Column(
          children: [
            Expanded(
              child: ChatFleather(controller: controller, onSubmit: send),
            ),
            SizedBox(
              height: custom.spacing.lg,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AgentSelector(),
                  ModelSelector(),
                  SizedBox(width: custom.spacing.xs),
                  SignalBuilder(
                    builder: (_) {
                      final sid = SessionStore.instance.selectedId.value;
                      final isStreaming =
                          sid != null &&
                          SessionStore.instance.streamingSessionIds.value
                              .contains(sid);
                      if (isStreaming) {
                        return AppIconButton(
                          icon: 'square',
                          size: ButtonSize.sm,
                          backgroundColor: custom.colors.danger,
                          tooltip: '停止生成',
                          onPressed: () =>
                              SessionStore.instance.cancelStreaming(sid),
                        );
                      }
                      return AppIconButton(
                        icon: 'arrowUpRight',
                        size: ButtonSize.sm,
                        backgroundColor: custom.colors.hover,
                        disabled: sending.value,
                        onPressed: send,
                      );
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
