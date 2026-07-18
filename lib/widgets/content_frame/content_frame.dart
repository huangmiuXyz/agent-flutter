import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/utils/layout_utils.dart';

/// A layout container that provides scroll, horizontal centering,
/// reading-width constraint, and page-level top/bottom spacing.
class ContentFrame extends HookConsumerWidget {
  final Widget child;

  const ContentFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = CustomTheme.of(context).spacing;
    final width = ref.watch(readingWidthProvider);
    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(
            top: spacing.pageTop,
            bottom: spacing.pageBottom,
          ),
          child: SizedBox(width: width, child: child),
        ),
      ),
    );
  }
}
