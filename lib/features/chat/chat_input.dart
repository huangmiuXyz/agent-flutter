import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agent/features/chat/chat_fleather.dart';
import 'package:agent/utils/layout_utils.dart';

class ChatInput extends ConsumerWidget {
  const ChatInput({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final physicalHeight = 200.0 / MediaQuery.of(context).devicePixelRatio;
    final readingWidth = ref.watch(readingWidthProvider);
    return SizedBox(
      width: readingWidth,
      height: physicalHeight,
      child: const ChatFleather(),
    );
  }
}
