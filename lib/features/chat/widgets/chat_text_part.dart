import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/store/theme_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/markdown/markdown_preview.dart';
import 'package:agent/widgets/text/code_block_view.dart';

import '../custom_tools_render/chat_diff_block.dart';

/// 文本 Part — 渲染纯文本或 Markdown 内容
///
/// 流式输出时增量渲染：新文本是已渲染文本的追加后缀时，只把增量部分
/// 喂给 [MarkdownPreviewController]，streamdown 只解析新增 chunk，
/// 避免每帧全量重解析整段 markdown（大文本下曾是主要卡顿源）。
/// 内容被整体替换（重试/历史加载等）时自动重建 controller。
class ChatTextPart extends HookWidget {
  /// 已落盘的完整内容
  final String content;

  /// 是否还在流式输出中
  final bool streaming;

  const ChatTextPart({super.key, this.content = '', this.streaming = false});

  /// 提取实际显示的文本（用户消息存的是 JSON 包裹格式 `{"content":"..."}`）
  static String extractDisplayText(String raw) {
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic> && parsed['content'] is String) {
        return parsed['content'] as String;
      }
    } catch (_) {}
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final text = extractDisplayText(content);

    // ── hooks（必须在所有提前返回之前调用）──
    // flutter_hooks 要求每次 build 的 hook 调用顺序一致；streaming 在
    // Done/Error 后翻转，同一 element 会在流式/非流式分支间切换，
    // 若 hook 放在提前返回之后会破坏顺序触发断言。
    final controllerRef = useRef<MarkdownPreviewController?>(null);
    final textRef = useRef('');
    // 是否曾以流式管线渲染：流结束后保持同一管线（done() 定型），
    // 不切回静态渲染重建，避免完成瞬间 1-2 帧空白闪动
    final everStreamedRef = useRef(false);
    // 卸载时释放最后一个 controller（streamdown 会自行取消订阅，
    // 这里只需关闭 StreamController；替换场景在下方即时 dispose）
    useEffect(() {
      return () => controllerRef.value?.dispose();
    }, []);

    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final custom = CustomTheme.of(context);
    // Markdown 渲染字体：Markdown 专用设置 > 界面字体设置（代码块不受影响，
    // 仍走 CodeBlockView 的等宽字体逻辑）
    final markdownFontFamily = useExistingSignal(
      ThemeStore.instance.markdownFontFamily,
    );
    final textStyle = textStyleForFont(
      markdownFontFamily.value ??
          custom.typography.effectiveFontFamily ??
          kDefaultFontFamily,
      fontSize: custom.typography.bodySize,
      color: custom.colors.textPrimary,
    );

    Widget codeBlockBuilder(
      BuildContext context,
      String? language,
      String code,
      bool isComplete,
    ) {
      final name = language?.toLowerCase();
      if (name == 'diff' || name == 'patch') {
        // 走 ChatDiffBlock：纯文件操作（删除/移动）不渲染代码块，
        // 仅以普通文本显示文件头；有代码内容才渲染 diff 代码块
        return ChatDiffBlock(diff: code);
      }
      return CodeBlockView(
        code: code,
        language: CodeBlockView.modeForFence(language),
      );
    }

    if (!streaming && !everStreamedRef.value) {
      // 非流式（历史加载/静态内容）：同步全量渲染，行为与 streamdown 的
      // text 模式一致（无订阅前缓冲/异步重放）
      return MarkdownPreview(
        text: text,
        selectable: true,
        textStyle: textStyle,
        codeBlockBuilder: codeBlockBuilder,
      );
    }

    // ── 流式增量渲染 ──
    // streamdown 的流式管线按行渲染：完整行随到达立即渲染；正在输入中
    // 的未完成行（无换行）由 tokenizer 缓冲，并通过 provisional 渲染
    // 即时显示（随内容增长原位替换），换行后按真实 markdown 语义定型。
    final controller = controllerRef.value ??= MarkdownPreviewController();
    if (streaming) {
      everStreamedRef.value = true;
      if (controller.isClosed) {
        // 完成态后再次进入流式（罕见）：旧流已关闭无法再 append，
        // 重建 controller 并重放全文
        final fresh = MarkdownPreviewController()..append(text);
        controllerRef.value = fresh;
        textRef.value = text;
        controller.dispose();
      } else {
        final prevText = textRef.value;
        if (text.length > prevText.length && text.startsWith(prevText)) {
          // 纯追加：只喂增量
          controller.append(text.substring(prevText.length));
          textRef.value = text;
        } else if (text != prevText) {
          // 非追加（整体替换/截断）：新建 controller，内容走订阅前缓冲。
          // controller.stream 是稳定实例，引用变化会让 Streamdown 的
          // didUpdateWidget 重建管线并重新订阅，无需额外重建信号；
          // 旧 controller 的订阅在同帧被取消，这里直接释放其资源。
          final fresh = MarkdownPreviewController()..append(text);
          controllerRef.value = fresh;
          textRef.value = text;
          controller.dispose();
        }
      }
    } else {
      // 流式完成（Done/Error）：不切回静态渲染 —— 静态是另一套
      // Streamdown.text 子树，重建管线 + 全量重解析在完成瞬间会有
      // 1-2 帧空白（贴底观看时的闪动）。保持同一 controller 管线，
      // 关闭流后 streamdown 在 onDone 定型最后一行（未闭合的代码
      // 围栏等），渲染结果与静态一致且不重建。
      if (!controller.isClosed) {
        controller.done();
      }
    }

    return MarkdownPreview(
      controller: controller,
      selectable: true,
      textStyle: textStyle,
      codeBlockBuilder: codeBlockBuilder,
    );
  }
}
