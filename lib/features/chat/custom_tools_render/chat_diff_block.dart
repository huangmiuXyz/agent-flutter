import 'package:flutter/material.dart';

import 'package:agent/features/chat/custom_tools_render/diff_code_block.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';

/// Diff 代码块 — 以 VSCode diff 视图样式渲染 apply_patch 补丁（工具参数专用）
///
/// 新增行绿色背景、删除行红色背景（整行铺满）、`@@` hunk 头蓝色、
/// `***` 信封行灰色，深色容器固定不随 app 亮暗切换；头部带 `diff`
/// 标签与一键复制按钮（复制保真）。
///
/// 纯文件操作（仅删除/移动文件，patch 中无代码内容行）不渲染代码块，
/// 改为以普通文本样式显示文件头（操作图标 + 路径）。
///
/// 流式渲染增量机制：Rust 端每事件推送「当前完整 patch 文本」，本组件
/// 内部用 [DiffParser] 增量解析（只处理新增文本），有内容行时转交
/// [DiffCodeBlock] 增量渲染，纯文件操作时增量维护文件头行 ——
/// 避免流式期间全量重解析与重建（大补丁下 O(n²) 卡顿）。
class ChatDiffBlock extends StatefulWidget {
  /// Unified diff 原文（可含 `\ No newline at end of file` 等尾注）
  final String diff;

  const ChatDiffBlock({super.key, required this.diff});

  @override
  State<ChatDiffBlock> createState() => _ChatDiffBlockState();
}

class _ChatDiffBlockState extends State<ChatDiffBlock> {
  DiffParser _parser = DiffParser();

  /// 文件头行数据（图标/颜色在 build 时按主题解析，主题切换自适应）
  final List<_HeaderRowData> _rows = [];
  String? _moveSource;
  int _handledHeaders = 0;

  @override
  void initState() {
    super.initState();
    _parser.feed(widget.diff);
    _consumeHeaders();
  }

  @override
  void didUpdateWidget(covariant ChatDiffBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final diff = widget.diff;
    if (diff == oldWidget.diff) return;
    final isAppend =
        diff.length > oldWidget.diff.length && diff.startsWith(oldWidget.diff);
    // 已进入 diff 代码块模式：内容交由 DiffCodeBlock 增量渲染，
    // 这里无需再解析（hasVisibleContent 一旦为真不会回退）
    if (_parser.hasVisibleContent && isAppend) return;
    if (isAppend) {
      _parser.feed(diff.substring(oldWidget.diff.length));
    } else {
      // 整体替换（重试/解码恢复/历史加载）：重置并全量解析
      _parser = DiffParser()..feed(diff);
      _rows.clear();
      _moveSource = null;
      _handledHeaders = 0;
    }
    _consumeHeaders();
  }

  /// 增量消费新到的文件头事件（只处理新增部分）
  void _consumeHeaders() {
    while (_handledHeaders < _parser.headers.length) {
      final (kind, path) = _parser.headers[_handledHeaders++];
      switch (kind) {
        case DiffLineKind.fileDelete:
          _rows.add(_HeaderRowData('trash', _HeaderColor.danger, '删除文件 $path'));
        case DiffLineKind.fileUpdate:
          // 移动由 `*** Update File: 源路径` + `*** Move to: 目标路径` 组成
          _moveSource = path;
        case DiffLineKind.fileMove:
          _rows.add(
            _HeaderRowData('move', _HeaderColor.accent, '移动文件 $_moveSource → $path'),
          );
        default:
          break; // 新建文件必有内容行，不会进入纯文件操作分支
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.diff.isEmpty) {
      return const SizedBox.shrink();
    }
    // 纯文件操作（patch 中无代码内容行）不渲染代码块。
    // 未完成行（如流式中 `+hel` 尚未换行）也算内容行（对齐全量解析语义）
    if (!_parser.hasVisibleContent) {
      return _buildFileHeaders(context);
    }
    return DiffCodeBlock(diff: widget.diff);
  }

  /// 纯文件操作：文件头行以普通文本样式显示（操作图标 + 路径）
  Widget _buildFileHeaders(BuildContext context) {
    final custom = CustomTheme.of(context);
    if (_rows.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  row.iconName,
                  size: 12,
                  color: switch (row.color) {
                    _HeaderColor.danger => custom.colors.danger,
                    _HeaderColor.accent => custom.colors.accent,
                  },
                ),
                const SizedBox(width: 6),
                SelectableText(
                  row.text,
                  style: TextStyle(
                    fontSize: custom.typography.captionSize,
                    color: custom.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 文件头行数据：build 时按当前主题解析图标颜色
class _HeaderRowData {
  const _HeaderRowData(this.iconName, this.color, this.text);

  final String iconName;
  final _HeaderColor color;
  final String text;
}

enum _HeaderColor { danger, accent }
