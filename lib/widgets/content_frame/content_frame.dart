import 'package:flutter/material.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/utils/layout_utils.dart';

/// A layout container that provides scroll, horizontal centering,
/// reading-width constraint, and page-level top/bottom spacing.
class ContentFrame extends StatelessWidget {
  final Widget child;

  const ContentFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final spacing = CustomTheme.of(context).spacing;
    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(
            top: spacing.pageTop,
            bottom: spacing.pageBottom,
          ),
          child: SizedBox(width: readingWidth(context), child: child),
        ),
      ),
    );
  }
}
