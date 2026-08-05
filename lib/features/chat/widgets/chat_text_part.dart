import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

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
    final flushedRef = useRef('');
    // 卸载时释放最后一个 controller（streamdown 会自行取消订阅，
    // 这里只需关闭 StreamController；替换场景在下方即时 dispose）
    useEffect(() {
      return () => controllerRef.value?.dispose();
    }, []);

    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final custom = CustomTheme.of(context);
    final textStyle = textStyleForFont(
      custom.typography.effectiveFontFamily ?? kDefaultFontFamily,
      fontSize: custom.typography.bodySize,
      color: custom.colors.textPrimary,
    );

    Widget codeBlockBuilder(BuildContext context, String? language, String code,
        bool isComplete) {
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

    // 非流式（历史加载/静态内容）：同步全量渲染，行为与 streamdown 的
    // text 模式一致（无订阅前缓冲/异步重放）
    if (!streaming) {
      return MarkdownPreview(
        text: text,
        selectable: true,
        textStyle: textStyle,
        codeBlockBuilder: codeBlockBuilder,
      );
    }

    // ── 流式增量渲染 ──
    // streamdown 的流式管线按行渲染：只有遇到 `\n` 的行才会输出 token，
    // 未结束的行（正在输入中的字）不会显示。因此把「完整行」喂给
    // [MarkdownPreviewController]（增量解析，避免每帧全量重解析），
    // 未完成的当前行单独用 [SelectableText] 实时渲染 —— 保证逐字输出效果。
    final lastNl = text.lastIndexOf('\n');
    final flushed = lastNl >= 0 ? text.substring(0, lastNl + 1) : '';
    final pendingLine = lastNl >= 0 ? text.substring(lastNl + 1) : text;

    final controller = controllerRef.value ??= MarkdownPreviewController();
    final prevFlushed = flushedRef.value;
    if (flushed.length > prevFlushed.length &&
        flushed.startsWith(prevFlushed)) {
      // 纯追加：只喂增量（完整行）
      controller.append(flushed.substring(prevFlushed.length));
      flushedRef.value = flushed;
    } else if (flushed != prevFlushed) {
      // 非追加（整体替换/截断）：新建 controller，内容走订阅前缓冲。
      // controller.stream 是稳定实例，引用变化会让 Streamdown 的
      // didUpdateWidget 重建管线并重新订阅，无需额外重建信号；
      // 旧 controller 的订阅在同帧被取消，这里直接释放其资源。
      final fresh = MarkdownPreviewController()..append(flushed);
      controllerRef.value = fresh;
      flushedRef.value = flushed;
      controller.dispose();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MarkdownPreview(
          controller: controller,
          selectable: true,
          textStyle: textStyle,
          codeBlockBuilder: codeBlockBuilder,
        ),
        // 未完成的当前行：实时逐字渲染（换行后交由 streamdown 渲染）。
        // 间距与 streamdown 段落间距（AstRenderer Column spacing: 12）
        // 保持一致 —— 否则换行瞬间行距突变（4px → 12px）。
        if (pendingLine.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: flushed.isNotEmpty ? 12 : 0),
            child: SelectableText(
              pendingLine,
              style: textStyle,
            ),
          ),
      ],
    );
  }
}
