import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/features/chat/panels/chat_content.dart';
import 'package:agent/features/chat/panels/left_panel.dart';
import 'package:agent/features/chat/panels/right_panel.dart';
import 'package:agent/features/chat/panels/terminal_panel.dart';
import 'package:agent/features/chat/panels/top_panel.dart';
import 'package:agent/widgets/resizebox/resizebox.dart';

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
        direction: ResizeDirection.left,
        minSize: 180,
        initialSize: 256,
        maxSize: 400,
        initialCollapsed: true,
        other: ResizeBox(
          direction: ResizeDirection.bottom,
          minSize: 30,
          initialSize: 40,
          maxSize: 120,
          collapseThreshold: 30,
          initialCollapsed: true,
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
          child: const TopPanel(),
        ),
        child: const RightPanel(),
      ),
      child: const LeftPanel(),
    );
  }
}
