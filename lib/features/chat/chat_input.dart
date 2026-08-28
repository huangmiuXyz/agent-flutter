import 'package:fleather/fleather.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/agents/widgets/agent_selector.dart';
import 'package:agent/features/chat/widgets/model_selector.dart';
import 'package:agent/features/chat/widgets/reasoning_selector.dart';
import 'package:agent/features/chat/widgets/work_dir_selector.dart';
import 'package:agent/features/chat/chat_fleather.dart';
import 'package:agent/services/image_store.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/store/xterm_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/utils/layout_utils.dart' show readingWidthFor;
import 'package:agent/utils/platform.dart';
import 'package:agent/widgets/text/app_text.dart';

import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';

class ChatInput extends HookWidget {
  const ChatInput({super.key, this.fullHeight = false});

  final bool fullHeight;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final mobile = isMobilePlatform;
    final physicalHeight = 160.0 / MediaQuery.of(context).devicePixelRatio;
    final width = readingWidthFor(context);
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
    // controller 由本组件创建并负责 dispose（ChatFleather 只 dispose 内部创建的）
    useEffect(
      () =>
          () => controller.dispose(),
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
        // 异步完成时组件可能已销毁（controller 已被 dispose），跳过清空
        if (ok && context.mounted) controller.clear();
      } finally {
        // 异步完成时组件可能已销毁，避免在已 dispose 的 notifier 上赋值
        if (context.mounted) sending.value = false;
      }

      // 发送完成后重新聚焦输入框（含点击发送按钮的场景）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) focusNode.requestFocus();
      });
    }

    /// 选择图片并插入 Fleather 文档（复制到 File 目录后按原始名引用）
    Future<void> pickImages() async {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (files.isEmpty) return;
      for (final file in files) {
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

    // 移动端「更多」底部弹层：收纳 work_dir / agent / model 选择器
    void showMoreSheet() {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: custom.spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _MoreSheetRow(label: '工作目录', child: WorkDirSelector()),
                _MoreSheetRow(label: '智能体', child: AgentSelector()),
                _MoreSheetRow(label: '模型', child: ModelSelector()),
              ],
            ),
          ),
        ),
      );
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
        height: fullHeight
            ? null
            : (mobile ? kMobileInputHeight : physicalHeight),
        child: Column(
          children: [
            Expanded(
              child: ChatFleather(
                controller: controller,
                focusNode: focusNode,
                onSubmit: send,
                // 空文档时显示占位提示
                placeholder: mobile ? '输入消息…' : 'Enter 键发送信息',
              ),
            ),
            SizedBox(
              height: custom.spacing.lg,
              child: Row(
                children: [
                  // 图片上传按钮固定在左侧
                  AppIconButton(
                    icon: 'image',
                    size: mobile ? ButtonSize.md : ButtonSize.sm,
                    tooltip: '上传图片',
                    onPressed: pickImages,
                  ),
                  SizedBox(width: custom.spacing.xs),
                  // 推理强度选择器（在按钮区域左侧）
                  ReasoningSelector(),
                  if (mobile) ...[
                    SizedBox(width: custom.spacing.xs),
                    // 移动端：work_dir/agent/model 收纳进底部弹层
                    AppIconButton(
                      icon: 'moreHorizontal',
                      size: ButtonSize.md,
                      tooltip: '更多',
                      onPressed: showMoreSheet,
                    ),
                  ],
                  const Spacer(),
                  if (!mobile) ...[
                    WorkDirSelector(),
                    SizedBox(width: custom.spacing.xs),
                    AgentSelector(),
                    SizedBox(width: custom.spacing.xs),
                    ModelSelector(),
                    SizedBox(width: custom.spacing.xs),
                  ],
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
                          size: mobile ? ButtonSize.md : ButtonSize.sm,
                          backgroundColor: custom.colors.danger,
                          iconColor: custom.colors.onDanger,
                          tooltip: '停止生成',
                          onPressed: () =>
                              SessionStore.instance.cancelStreaming(sid),
                        );
                      }
                      return AppIconButton(
                        icon: 'arrowUpRight',
                        size: mobile ? ButtonSize.md : ButtonSize.sm,
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

/// 移动端输入区固定高度（逻辑像素）：编辑区 + 工具栏行。
/// 桌面沿用物理 160/dpr；移动端 devicePixelRatio ~3 会算出 ~53dp 过矮。
const double kMobileInputHeight = 108.0;

/// 「更多」弹层中的一行：左侧标签 + 右侧选择器。
class _MoreSheetRow extends StatelessWidget {
  const _MoreSheetRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: custom.spacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: AppText(
              label,
              variant: AppTextVariant.body,
              color: custom.colors.textSecondary,
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
