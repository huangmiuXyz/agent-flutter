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
class ChatDiffBlock extends StatelessWidget {
  /// Unified diff 原文（可含 `\ No newline at end of file` 等尾注）
  final String diff;

  const ChatDiffBlock({super.key, required this.diff});

  @override
  Widget build(BuildContext context) {
    if (diff.isEmpty) {
      return const SizedBox.shrink();
    }
    // 纯文件操作（patch 中无代码内容行）不渲染代码块
    final hasContentLines = diff.split('\n').any((line) {
      final trimmed = line.trimLeft();
      return trimmed.isNotEmpty &&
          !trimmed.startsWith('***') &&
          !trimmed.startsWith('@@') &&
          !trimmed.startsWith('\\ No newline');
    });
    if (!hasContentLines) {
      return _buildFileHeaders(context);
    }
    return DiffCodeBlock(diff: diff);
  }

  /// 纯文件操作：解析文件头（删除/移动），以普通文本样式显示，非代码块
  Widget _buildFileHeaders(BuildContext context) {
    final custom = CustomTheme.of(context);
    final rows = <Widget>[];
    // 移动由 `*** Update File: 源路径` + `*** Move to: 目标路径` 组成
    String? moveSource;
    for (final line in diff.split('\n')) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('*** Delete File: ')) {
        rows.add(
          _headerRow(
            custom,
            'trash',
            custom.colors.danger,
            '删除文件 ${trimmed.substring('*** Delete File: '.length)}',
          ),
        );
      } else if (trimmed.startsWith('*** Update File: ')) {
        moveSource = trimmed.substring('*** Update File: '.length);
      } else if (trimmed.startsWith('*** Move to: ')) {
        rows.add(
          _headerRow(
            custom,
            'move',
            custom.colors.accent,
            '移动文件 $moveSource → ${trimmed.substring('*** Move to: '.length)}',
          ),
        );
      }
    }
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }

  /// 文件头行：操作图标 + 文本（普通字体，非代码块样式）
  Widget _headerRow(
    CustomTheme custom,
    String iconName,
    Color color,
    String text,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(iconName, size: 12, color: color),
          const SizedBox(width: 6),
          SelectableText(
            text,
            style: TextStyle(
              fontSize: custom.typography.captionSize,
              color: custom.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
