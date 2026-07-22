import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 文本 Part — 渲染纯文本或 Markdown 内容
///
/// 支持流式增量内容（通过 [streamingContent] 传入实时累积的文本）。
class ChatTextPart extends StatelessWidget {
  /// 已落盘的完整内容
  final String content;

  /// 流式累积内容（非 null 时覆盖 [content] 用于实时显示）
  final String? streamingContent;

  const ChatTextPart({
    super.key,
    this.content = '',
    this.streamingContent,
  });

  /// 提取实际显示的文本（用户消息存的是 JSON 包裹格式 `{"content":"..."}`）
  static String _extractDisplayText(String raw) {
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
    final custom = CustomTheme.of(context);
    final raw = streamingContent ?? content;
    final text = _extractDisplayText(raw);

    if (text.isEmpty) {
      // 没有 streaming 也没有已落盘内容 → 完全不渲染
      if (streamingContent == null || streamingContent!.isEmpty) {
        return const SizedBox.shrink();
      }
      // 有 streaming 但还没内容 → 显示光标占位
      return SizedBox(
        height: 20,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 8,
            height: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: custom.colors.textSecondary.withValues(alpha: 0.4),
                borderRadius: custom.radii.xs,
              ),
            ),
          ),
        ),
      );
    }

    return AppText(
      text,
      variant: AppTextVariant.body,
    );
  }
}
