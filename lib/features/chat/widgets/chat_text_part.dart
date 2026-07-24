import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:agent/theme/app_tokens.dart';
import 'package:agent/widgets/markdown/markdown_preview.dart';

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

    return MarkdownPreview(
      text: text,
      selectable: true,
      textStyle: TextStyle(fontFamily: defaultFontFamily),
    );
  }
}
