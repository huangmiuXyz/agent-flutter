import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/card/app_card.dart';
import 'package:agent/widgets/text/app_text.dart';

import 'chat_expandable_part.dart';
import 'chat_text_part.dart';

/// Intent signalled when user presses Enter (without modifiers) to retry.
class _RetryIntent extends Intent {
  const _RetryIntent();
}

/// Action that invokes the [onSubmit] callback.
class _RetryAction extends Action<_RetryIntent> {
  _RetryAction({this.onSubmit});

  final VoidCallback? onSubmit;

  @override
  void invoke(_RetryIntent intent) {
    onSubmit?.call();
  }
}

/// 用户消息编辑重试回调
///
/// [msgId] 要重试的消息 ID，[newContent] 编辑后的文本。
typedef OnRetryMessage = void Function(String msgId, String newContent);

/// 用户消息 — 支持点击编辑，回车重试
class _UserMessage extends HookWidget {
  final String sessionId;
  final String msgId;
  final List<api.PartInfo> visibleParts;
  final CustomTheme custom;
  final double minPartHeight;
  final OnRetryMessage? onRetry;
  final ValueChanged<bool>? onFocusChanged;

  const _UserMessage({
    required this.sessionId,
    required this.msgId,
    required this.visibleParts,
    required this.custom,
    required this.minPartHeight,
    this.onRetry,
    this.onFocusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = useTextEditingController();

    // 找到第一个 text part 的内容作为初始值
    final textPart = visibleParts.cast<api.PartInfo?>().firstWhere(
      (p) => p!.partType == 'text',
      orElse: () => null,
    );
    final initialText = textPart != null ? ChatTextPart.extractDisplayText(textPart.content) : '';

    useEffect(() {
      ctrl.text = initialText;
      return null;
    }, [initialText]);

    final focusNode = useFocusNode();

    useEffect(() {
      void onFocus() => onFocusChanged?.call(focusNode.hasFocus);
      focusNode.addListener(onFocus);
      return () => focusNode.removeListener(onFocus);
    }, [focusNode, onFocusChanged]);

    void handleSubmit() {
      final newText = ctrl.text.trim();
      if (newText.isEmpty) return;
      focusNode.unfocus();
      onRetry?.call(msgId, newText);
    }

    final messagePadding = EdgeInsets.symmetric(
      horizontal: custom.spacing.md,
      vertical: custom.spacing.xs,
    );

    return Padding(
      padding: messagePadding,
      child: AppCard(
        padding: EdgeInsets.all(custom.spacing.xs),
        child: Shortcuts(
          shortcuts: {
            // Enter without modifiers → submit; Shift+Enter passes through as newline
            SingleActivator(LogicalKeyboardKey.enter): const _RetryIntent(),
          },
          child: Actions(
            actions: {
              _RetryIntent: _RetryAction(onSubmit: handleSubmit),
            },
            child: TextField(
              focusNode: focusNode,
              controller: ctrl,
              maxLines: null,
              style: TextStyle(
                fontSize: custom.typography.bodySize,
                fontFamily: custom.typography.fontFamily,
                color: custom.colors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

}

/// 单条消息的渲染组件
///
/// 接收 [parts] 直接渲染，流式内容由父级通过更新 parts 实现。
///
/// 用户消息支持点击编辑，回车重试。
class ChatMessageItem extends HookWidget {
  final String sessionId;
  final String msgId;
  final String role;
  final List<api.PartInfo> parts;
  final Map<String, String> toolCallResults;

  /// 是否允许自动展开本消息内的最后一个可展开 part。
  /// 仅在全局最后一条有 expandable part 的消息上为 true。
  final bool autoExpandLast;

  /// 模型名称（仅第一条 assistant 消息有值，其余为 null）
  final String? modelName;

  /// 用户消息编辑重试回调
  final OnRetryMessage? onRetry;

  /// 后续消息被聚焦编辑时，本消息变灰提示将被删除
  final bool dimmed;

  /// 焦点变化回调
  final ValueChanged<bool>? onFocusChanged;

  const ChatMessageItem({
    super.key,
    required this.sessionId,
    required this.msgId,
    required this.role,
    required this.parts,
    this.toolCallResults = const {},
    this.autoExpandLast = false,
    this.modelName,
    this.onRetry,
    this.dimmed = false,
    this.onFocusChanged,
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

    // 用户消息：支持点击编辑
    if (role == 'user') {
      return _UserMessage(
        sessionId: sessionId,
        msgId: msgId,
        visibleParts: visibleParts,
        custom: custom,
        minPartHeight: minPartHeight,
        onRetry: onRetry,
        onFocusChanged: onFocusChanged,
      );
    }

    // 模型标签（仅第一条 assistant 消息显示）
    final modelBadge = modelName != null && role == 'assistant'
        ? Padding(
            padding: EdgeInsets.only(bottom: custom.spacing.sm),
            child: AppText(
              modelName!,
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
            ),
          )
        : null;

    final lastExpandableIndex = _lastExpandablePartIndex(visibleParts);
    final effectiveLastIdx = autoExpandLast ? lastExpandableIndex : -1;

    final partsWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (modelBadge != null) modelBadge,
        for (int i = 0; i < visibleParts.length; i++)
          _buildPartWithSpacing(
            i, visibleParts, custom, minPartHeight,
            isLastExpandable: i == effectiveLastIdx,
          ),
      ],
    );

    final messagePadding = EdgeInsets.symmetric(
      horizontal: custom.spacing.md,
      vertical: custom.spacing.xs,
    );

    Widget result = Padding(padding: messagePadding, child: partsWidget);
    if (dimmed) {
      result = Opacity(opacity: 0.35, child: result);
    }
    return result;
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
    if (part.partType == 'reasoning') {
      return part.content.isNotEmpty;
    }
    return part.partType == 'tool_call';
  }

  Widget _buildPartWithSpacing(
    int index,
    List<api.PartInfo> visibleParts,
    CustomTheme custom,
    double minPartHeight, {
    bool isLastExpandable = false,
  }) {
    final part = visibleParts[index];
    final widget = _buildPart(part, custom, isLastExpandable: isLastExpandable);
    final constrained = Container(
      constraints: BoxConstraints(minHeight: minPartHeight),
      alignment: Alignment.centerLeft,
      child: widget,
    );
    if (index < visibleParts.length - 1) {
      return Padding(
        padding: EdgeInsets.only(bottom: custom.spacing.sm),
        child: constrained,
      );
    }
    return constrained;
  }

  Widget _buildPart(api.PartInfo part, CustomTheme custom, {
    bool isLastExpandable = false,
  }) {
    return switch (part.partType) {
      'text' => ChatTextPart(content: part.content),
      'reasoning' => ChatExpandablePart(
        content: part.content,
        iconName: 'lightbulb',
        title: '深度思考',
        titleColor: custom.colors.textSecondary,
        defaultExpanded: isLastExpandable,
      ),
      'tool_call' => ChatExpandablePart(
        content: part.content,
        iconName: 'mousePointer2',
        title: _toolCallTitle(part.content),
        titleColor: custom.colors.accent,
        defaultExpanded: isLastExpandable,
        resultContent: _lookupResult(part.content),
      ),
      'tool_result' => const SizedBox.shrink(),
      'tool_call_frag' => _buildFragPart(part, custom, isLastExpandable: isLastExpandable),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildFragPart(api.PartInfo part, CustomTheme custom, {
    bool isLastExpandable = false,
  }) {
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
      defaultExpanded: isLastExpandable,
    );
  }

  /// 找出最后一个可展开 part 的索引（reasoning / tool_call / tool_call_frag）
  // ── widget 内部方法 ──
  int _lastExpandablePartIndex(List<api.PartInfo> parts) {
    int lastIdx = -1;
    for (int i = 0; i < parts.length; i++) {
      if (_isExpandable(parts[i])) {
        lastIdx = i;
      }
    }
    return lastIdx;
  }

  bool _isExpandable(api.PartInfo part) {
    return part.partType == 'reasoning' ||
        part.partType == 'tool_call' ||
        part.partType == 'tool_call_frag';
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
