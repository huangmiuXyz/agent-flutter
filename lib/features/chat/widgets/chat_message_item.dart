import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/card/app_card.dart';

import 'chat_expandable_part.dart';
import 'chat_text_part.dart';

/// 单条消息的渲染组件
///
/// 接收 [parts] 直接渲染，流式内容由父级通过更新 parts 实现。
class ChatMessageItem extends StatelessWidget {
  final String sessionId;
  final String msgId;
  final String role;
  final List<api.PartInfo> parts;
  final Map<String, String> toolCallResults;

  const ChatMessageItem({
    super.key,
    required this.sessionId,
    required this.msgId,
    required this.role,
    required this.parts,
    this.toolCallResults = const {},
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    // 按 seq 排序 parts，过滤掉永远不可见的类型
    final sortedParts = List<api.PartInfo>.from(parts)
      ..sort((a, b) => a.seq.compareTo(b.seq));
    final visibleParts = sortedParts
        .where((p) => _isVisiblePart(p, sortedParts))
        .toList();

    if (visibleParts.isEmpty) {
      return const SizedBox.shrink();
    }

    final minPartHeight = custom.controls.chatPartCollapsedHeight;

    final partsWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < visibleParts.length; i++)
          _buildPartWithSpacing(i, visibleParts, custom, minPartHeight),
      ],
    );

    final messagePadding = EdgeInsets.symmetric(
      horizontal: custom.spacing.md,
      vertical: custom.spacing.xs,
    );

    if (role == 'user') {
      return Padding(
        padding: messagePadding,
        child: AppCard(
          padding: EdgeInsets.symmetric(
            horizontal: custom.spacing.xs,
            vertical: 0,
          ),
          child: partsWidget,
        ),
      );
    }

    return Padding(padding: messagePadding, child: partsWidget);
  }

  bool _isVisiblePart(api.PartInfo part, List<api.PartInfo> allParts) {
    if (part.partType == 'tool_result') return false;
    if (part.partType == 'tool_call_frag') {
      if (allParts.any((p) => p.partType == 'tool_call')) return false;
      return part.content.isNotEmpty;
    }
    if (part.partType == 'text') {
      return part.content.isNotEmpty;
    }
    return part.partType == 'tool_call';
  }

  Widget _buildPartWithSpacing(
    int index,
    List<api.PartInfo> visibleParts,
    CustomTheme custom,
    double minPartHeight,
  ) {
    final part = visibleParts[index];
    final widget = _buildPart(part, custom);
    final constrained = Container(
      constraints: BoxConstraints(minHeight: minPartHeight),
      alignment: Alignment.centerLeft,
      child: widget,
    );
    if (index < visibleParts.length - 1) {
      return Padding(
        padding: EdgeInsets.only(bottom: custom.spacing.xs),
        child: constrained,
      );
    }
    return constrained;
  }

  Widget _buildPart(api.PartInfo part, CustomTheme custom) {
    return switch (part.partType) {
      'text' => ChatTextPart(content: part.content),
      'tool_call' => ChatExpandablePart(
        content: part.content,
        iconName: 'mousePointer2',
        title: _toolCallTitle(part.content),
        titleColor: custom.colors.accent,
        defaultExpanded: false,
        resultContent: _lookupResult(part.content),
      ),
      'tool_result' => const SizedBox.shrink(),
      'tool_call_frag' => _buildFragPart(part, custom),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildFragPart(api.PartInfo part, CustomTheme custom) {
    final raw = part.content;
    if (raw.isEmpty) return const SizedBox.shrink();

    String title;
    String? fragTitle;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final name = json['name'] as String?;
      fragTitle = name != null && name.isNotEmpty ? '工具调用: $name' : null;
    } catch (_) {}
    title = fragTitle ?? '工具调用…';

    return ChatExpandablePart(
      content: raw,
      iconName: 'mousePointer2',
      title: title,
      titleColor: custom.colors.accent,
      defaultExpanded: false,
    );
  }

  String? _lookupResult(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      // 从 DB 加载后的路径：按 tool_call_id 查找 tool_result
      final id = json['id'] as String?;
      if (id != null && toolCallResults.containsKey(id)) {
        return toolCallResults[id];
      }
      // 流式路径：检查内联的 _result（由 StreamEventProcessor.handleToolCall 写入）
      final inlineResult = json['_result'] as String?;
      if (inlineResult != null && inlineResult.isNotEmpty) {
        return inlineResult;
      }
    } catch (_) {}
    return null;
  }

  String _toolCallTitle(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      final function = json['function'] as Map<String, dynamic>?;
      final name = function?['name'] as String?;
      if (name != null && name.isNotEmpty) return '工具调用: $name';
    } catch (_) {}
    return '工具调用';
  }
}
