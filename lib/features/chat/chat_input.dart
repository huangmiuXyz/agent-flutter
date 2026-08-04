import 'package:fleather/fleather.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/agents/widgets/agent_selector.dart';
import 'package:agent/features/chat/widgets/model_selector.dart';
import 'package:agent/features/chat/chat_fleather.dart';
import 'package:agent/services/image_store.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/store/xterm_store.dart';
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
    final physicalHeight = 160.0 / MediaQuery.of(context).devicePixelRatio;
    final width = readingWidth;
    final controller = useMemoized(() => FleatherController());
    final sending = useState(false);
    // 外部可控制的 FocusNode：快捷键折叠终端面板时聚焦聊天输入框
    final focusNode = useMemoized(() => FocusNode());

    // 快捷键/命令折叠终端面板时，把光标聚焦到聊天输入框
    final chatFocusCount = useExistingSignal(
      XtermStore.instance.chatFocusRequestCount,
    );
    useEffect(() {
      if (chatFocusCount.value > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            focusNode.requestFocus();
          }
        });
      }
      return null;
    }, [chatFocusCount.value]);

    useEffect(
      () =>
          () => focusNode.dispose(),
      [],
    );

    Future<void> send() async {
      final compose = extractChatCompose(controller);
      final text = compose.text.replaceAll('\n', '').trim();
      if (text.isEmpty && compose.imagePaths.isEmpty) return;

      sending.value = true;
      try {
        // 统一入口：流式输出中自动入队（带图片时不可入队，返回 false
        // 并保留输入内容）；模型未配置时保留输入框内容
        final ok = await SessionStore.instance.sendPrompt(
          text,
          imagePaths: compose.imagePaths,
          imageNames: compose.imageNames,
        );
        if (ok) controller.clear();
      } finally {
        sending.value = false;
      }

      // 发送完成后重新聚焦输入框（含点击发送按钮的场景）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) focusNode.requestFocus();
      });
    }

    /// 选择图片并插入 Fleather 文档（复制到 File 目录后按原始名引用）
    Future<void> pickImages() async {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;
      for (final file in result.files) {
        final src = file.path;
        if (src == null) continue;
        try {
          final img = await ImageStore.instance.importImage(src);
          insertImageTag(
            controller,
            img.path,
            img.storedName,
            displayName: img.displayName,
          );
        } catch (_) {
          // 复制失败跳过该图片，不影响其余图片
        }
      }
      focusNode.requestFocus();
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
              child: ChatFleather(
                controller: controller,
                focusNode: focusNode,
                onSubmit: send,
                // 空文档时显示占位提示
                placeholder: 'Enter 键发送信息',
              ),
            ),
            SizedBox(
              height: custom.spacing.lg,
              child: Row(
                children: [
                  // 图片上传按钮固定在左侧
                  AppIconButton(
                    icon: 'image',
                    size: ButtonSize.sm,
                    tooltip: '上传图片',
                    onPressed: pickImages,
                  ),
                  const Spacer(),
                  AgentSelector(),
                  SizedBox(width: custom.spacing.xs),
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
                          iconColor: custom.colors.onDanger,
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
