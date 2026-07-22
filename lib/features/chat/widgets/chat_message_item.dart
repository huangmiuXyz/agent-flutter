import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/services/llm_providers.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/card/app_card.dart';

import 'chat_expandable_part.dart';
import 'chat_text_part.dart';

/// 单条消息的渲染组件
///
/// 流式更新通过监听 [SessionManager.streamingNotifier] 实现：
/// 只在当前消息的 part 有流式内容时重建，不影响列表中其他消息。
class ChatMessageItem extends HookConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = CustomTheme.of(context);

    final manager = ref.watch(sessionManagerProvider);

    // 当前消息中需要监听流式更新的 part ID 集合（text + tool_call_frag）
    final watchedPartIds = useMemoized(
      () => parts
          .where((p) => p.partType == 'text' || p.partType == 'tool_call_frag')
          .map((p) => p.id)
          .toSet(),
      [parts],
    );

    // 流式累积内容（文本 + tool_call_frag）
    // 初始化时直接从 sessionState.streamingContent 捞已有数据，避免错过事件
    final streamingContent = useState(<String, String>{});
    useEffect(() {
      // 先把 session 中已有的 streaming content 同步到本地
      final existing = manager.state[sessionId]?.streamingContent ?? {};
      final updated = Map<String, String>.from(streamingContent.value);
      bool changed = false;
      for (final id in watchedPartIds) {
        final content = existing[id];
        if (content != null && content.isNotEmpty && updated[id] != content) {
          updated[id] = content;
          changed = true;
        }
      }
      if (changed) streamingContent.value = updated;

      // 监听后续 streamingNotifier 事件
      void listener() {
        final partId = manager.streamingNotifier.value;
        if (partId != null && watchedPartIds.contains(partId)) {
          final content =
              manager.state[sessionId]?.streamingContent[partId] ?? '';
          streamingContent.value = {...streamingContent.value, partId: content};
        }
      }
      manager.streamingNotifier.addListener(listener);
      return () => manager.streamingNotifier.removeListener(listener);
    }, [manager, watchedPartIds]);

    // 按 seq 排序 parts，过滤掉永远不可见的类型
    final sortedParts = List<api.PartInfo>.from(parts)
      ..sort((a, b) => a.seq.compareTo(b.seq));
    final visibleParts =
        sortedParts.where((p) => _isVisiblePart(p, sortedParts, streamingContent.value)).toList();

    // 全不可见 → 跳过
    if (visibleParts.isEmpty) {
      return const SizedBox.shrink();
    }

    final minPartHeight = custom.controls.chatPartCollapsedHeight;

    final partsWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < visibleParts.length; i++)
          _buildPartWithSpacing(i, visibleParts, streamingContent.value, custom, minPartHeight),
      ],
    );

    final messagePadding = EdgeInsets.symmetric(
      horizontal: custom.spacing.md,
      vertical: custom.spacing.xs,
    );

    // 用户消息用 AppCard 包裹
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

    return Padding(
      padding: messagePadding,
      child: partsWidget,
    );
  }

  /// 判断 part 是否会产生可见 widget
  bool _isVisiblePart(
    api.PartInfo part,
    List<api.PartInfo> allParts,
    Map<String, String> streamingData,
  ) {
    if (part.partType == 'tool_result') return false;
    if (part.partType == 'tool_call_frag') {
      // 如果同消息已有最终 tool_call，隐藏流式中间态
      if (allParts.any((p) => p.partType == 'tool_call')) return false;
      final raw = streamingData[part.id] ?? part.content;
      return raw.isNotEmpty;
    }
    if (part.partType == 'text') {
      if (part.content.isNotEmpty) return true;
      final s = streamingData[part.id];
      return s != null && s.isNotEmpty;
    }
    return part.partType == 'tool_call';
  }

  /// 渲染单个可见 part，非最后一个时添加统一间距
  Widget _buildPartWithSpacing(
    int index,
    List<api.PartInfo> visibleParts,
    Map<String, String> streamingData,
    CustomTheme custom,
    double minPartHeight,
  ) {
    final part = visibleParts[index];
    final widget = _buildPart(part, streamingData, custom);
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

  Widget _buildPart(
      api.PartInfo part, Map<String, String> streamingData, CustomTheme custom) {
    return switch (part.partType) {
      'text' => ChatTextPart(
        content: part.content,
        streamingContent: streamingData[part.id],
      ),
      'tool_call' => ChatExpandablePart(
        content: part.content,
        iconName: 'mousePointer2',
        title: _toolCallTitle(part.content),
        titleColor: custom.colors.accent,
        defaultExpanded: false,
        resultContent: _lookupResult(part.content),
      ),
      'tool_result' => const SizedBox.shrink(),
      'tool_call_frag' => _buildFragPart(part, streamingData[part.id], custom),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildFragPart(
      api.PartInfo part, String? streamingData, CustomTheme custom) {
    // 优先使用流式累积内容，其次使用 part.content
    final raw = streamingData ?? part.content;
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
      final id = json['id'] as String?;
      if (id != null && toolCallResults.containsKey(id)) {
        return toolCallResults[id];
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
