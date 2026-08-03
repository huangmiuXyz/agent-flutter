import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/rust_bridge/api/types.dart' as api;
import 'package:agent/services/session/part_types.dart';
import 'package:agent/theme/custom_theme.dart';

import 'package:agent/widgets/text/app_text.dart';

import 'chat_expandable_part.dart';
import 'chat_search_part.dart';
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
      (p) => p!.partType == PartTypes.text,
      orElse: () => null,
    );
    final initialText = textPart != null
        ? ChatTextPart.extractDisplayText(textPart.content)
        : '';

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
      vertical: custom.spacing.sm,
    );

    return Padding(
      padding: messagePadding,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: custom.colors.cardBackground,
          borderRadius: custom.radii.sm,
          border: Border.all(color: custom.colors.cardBorder, width: 1),
          boxShadow: custom.shadows.small,
        ),
        padding: EdgeInsets.all(custom.spacing.xs),
        child: Shortcuts(
          shortcuts: {
            // Enter without modifiers → submit; Shift+Enter passes through as newline
            SingleActivator(LogicalKeyboardKey.enter): const _RetryIntent(),
          },
          child: Actions(
            actions: {_RetryIntent: _RetryAction(onSubmit: handleSubmit)},
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

  /// 当前会话是否处于流式输出中（传递给 ChatTextPart 用于增量追加）
  final bool streaming;

  const ChatMessageItem({
    super.key,
    required this.sessionId,
    required this.msgId,
    required this.role,
    required this.parts,
    this.autoExpandLast = false,
    this.modelName,
    this.onRetry,
    this.dimmed = false,
    this.onFocusChanged,
    this.streaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    // parts 列表本身即是时间顺序：流式按事件到达追加，重载按 DB 行序（rowid）
    // 返回。不要按 seq 排序 —— 预创建部件（text）的 seq 固定为 1，而搜索/
    // 工具卡片发生在回答之前，seq 会把它俩错排到答案后面。
    final visibleParts = parts.where((p) => _isVisiblePart(p)).toList();

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

    // 完全按 parts 原始顺序渲染：不做任何合并/拆分/移动，
    // 每个 part 按自身类型显示（思考、搜索、答案各归其位）。
    final lastExpandableIndex = _lastExpandablePartIndex(visibleParts);
    final effectiveLastIdx = autoExpandLast ? lastExpandableIndex : -1;

    final partsWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ?modelBadge,
        for (int i = 0; i < visibleParts.length; i++)
          _buildPartWithSpacing(
            i,
            visibleParts,
            custom,
            minPartHeight,
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

  bool _isVisiblePart(api.PartInfo part) {
    if (part.partType == PartTypes.toolResult) return false;
    if (part.partType == PartTypes.text) {
      return part.content.isNotEmpty;
    }
    if (part.partType == PartTypes.reasoning) {
      return part.content.isNotEmpty;
    }
    if (part.partType == PartTypes.webSearch) {
      return part.content.isNotEmpty;
    }
    // tool_call / tool_call_frag 是同一个调用生命周期内的两种状态，都展示
    return part.partType == PartTypes.toolCall ||
        part.partType == PartTypes.toolCallFrag;
  }

  /// 找出最后一个可展开 part 的索引（reasoning / tool_call / tool_call_frag）
  static int _lastExpandablePartIndex(List<api.PartInfo> parts) {
    int lastIdx = -1;
    for (int i = 0; i < parts.length; i++) {
      if (PartTypes.isExpandable(parts[i].partType)) {
        lastIdx = i;
      }
    }
    return lastIdx;
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

  Widget _buildPart(
    api.PartInfo part,
    CustomTheme custom, {
    bool isLastExpandable = false,
  }) {
    return switch (part.partType) {
      PartTypes.text => ChatTextPart(
        content: part.content,
        streaming: streaming,
      ),
      PartTypes.reasoning => ChatExpandablePart(
        content: part.content,
        iconName: 'lightbulb',
        title: '深度思考',
        titleColor: custom.colors.textSecondary,
        defaultExpanded: isLastExpandable,
      ),
      PartTypes.toolCall || PartTypes.toolCallFrag => ChatExpandablePart(
        content: part.content,
        iconName: 'mousePointer2',
        title: _toolCallTitle(part.content),
        titleColor: custom.colors.accent,
        defaultExpanded: isLastExpandable,
        resultContent: _lookupResult(part.content),
      ),
      PartTypes.toolResult => const SizedBox.shrink(),
      PartTypes.webSearch => ChatSearchPart(content: part.content),
      _ => const SizedBox.shrink(),
    };
  }

  /// 读取工具调用结果：内嵌在 part 内容里的 `_result`（完成时由 Rust 写入）。
  String? _lookupResult(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
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
