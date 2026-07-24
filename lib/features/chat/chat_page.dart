import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/features/chat/panels/chat_content.dart';
import 'package:agent/features/chat/panels/left_panel.dart';
import 'package:agent/features/chat/panels/terminal_panel.dart';
import 'package:agent/widgets/resizebox/resizebox.dart';

/// Chat page layout.
///
/// Temporarily removed:
/// - RightPanel (right_panel.dart)
/// - TopPanel  (top_panel.dart)
/// Re-enable by restoring the nested ResizeBox wrappers and imports.
class ChatDemo extends HookConsumerWidget {
  const ChatDemo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResizeBox(
      direction: ResizeDirection.right,
      minSize: 180,
      initialSize: 256,
      maxSize: 400,
      other: ResizeBox(
        direction: ResizeDirection.top,
        minSize: 100,
        initialSize: 250,
        maxSize: 500,
        collapseThreshold: 80,
        initialCollapsed: true,
        other: const ChatContent(),
        child: const TerminalPanel(),
      ),
      child: const LeftPanel(),
    );
  }
}
