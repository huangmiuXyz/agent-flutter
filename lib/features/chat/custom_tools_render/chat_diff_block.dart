import 'package:flutter/material.dart';

import 'package:agent/features/chat/custom_tools_render/diff_code_block.dart';

/// Diff 代码块 — 以 VSCode diff 视图样式渲染 apply_patch 补丁（工具参数专用）
///
/// 新增行绿色背景、删除行红色背景（整行铺满）、`@@` hunk 头蓝色、
/// `***` 信封行灰色，深色容器固定不随 app 亮暗切换；头部带 `diff`
/// 标签与一键复制按钮（复制保真）。
class ChatDiffBlock extends StatelessWidget {
  /// Unified diff 原文（可含 `\ No newline at end of file` 等尾注）
  final String diff;

  const ChatDiffBlock({super.key, required this.diff});

  @override
  Widget build(BuildContext context) {
    if (diff.isEmpty) {
      return const SizedBox.shrink();
    }
    return DiffCodeBlock(diff: diff);
  }
}
