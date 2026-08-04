import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/markdown/markdown_preview.dart';
import 'package:agent/widgets/text/code_block_view.dart';

import '../custom_tools_render/diff_code_block.dart';

/// 文本 Part — 渲染纯文本或 Markdown 内容
class ChatTextPart extends StatelessWidget {
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

    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final custom = CustomTheme.of(context);

    return MarkdownPreview(
      text: text,
      selectable: true,
      textStyle: textStyleForFont(
        custom.typography.effectiveFontFamily ?? kDefaultFontFamily,
        fontSize: custom.typography.bodySize,
        color: custom.colors.textPrimary,
      ),
      // 代码块统一走自研渲染：diff 语言用 VSCode diff 样式（绿红行背景），
      // 其余语言用深色代码块（streamdown 默认浅色主题在亮色 UI 下近乎
      // 无背景，且 flutter_highlight 存在样式丢失问题）
      codeBlockBuilder: (context, language, code, isComplete) {
        final name = language?.toLowerCase();
        if (name == 'diff' || name == 'patch') {
          return DiffCodeBlock(diff: code);
        }
        return CodeBlockView(
          code: code,
          language: CodeBlockView.modeForFence(language),
        );
      },
    );
  }
}
