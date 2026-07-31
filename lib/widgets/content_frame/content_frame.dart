import 'package:flutter/material.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/utils/layout_utils.dart' show readingWidth;

/// A layout container that provides scroll, horizontal centering,
/// reading-width constraint, and page-level top/bottom spacing.
///
/// When [scrollable] is false, the [child] is rendered without a wrapping
/// [SingleChildScrollView], allowing an inner [ListView.builder] to own the
/// scroll. Use this for virtualized lists with [AppBigList.sections].
class ContentFrame extends StatelessWidget {
  final Widget child;

  /// Whether to wrap [child] in a [SingleChildScrollView].
  ///
  /// Set to false when [child] is a virtualized list (e.g. [AppBigList]
  /// with [AppBigList.sections]) that provides its own scrolling.
  final bool scrollable;

  const ContentFrame({super.key, required this.child, this.scrollable = true});

  @override
  Widget build(BuildContext context) {
    final spacing = CustomTheme.of(context).spacing;

    final padded = Padding(
      padding: EdgeInsets.only(
        top: spacing.pageTop,
        bottom: spacing.sm,
        left: spacing.edgeMargin,
        right: spacing.edgeMargin,
      ),
      child: SizedBox(width: readingWidth, child: child),
    );

    if (!scrollable) {
      // Pass through bounded height so inner [Expanded] / [ListView.builder]
      // can virtualize. Without this, [Align] with loose constraints would
      // make the child measure itself, losing the viewport height.
      //
      // Only the height is forced: forcing the width would defeat [Align]'s
      // horizontal centering of the reading-width content (the Padding would
      // fill the full width and pin its child to the left edge).
      return LayoutBuilder(
        builder: (ctx, constraints) {
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : null,
              child: padded,
            ),
          );
        },
      );
    }

    return SingleChildScrollView(
      child: Align(alignment: Alignment.topCenter, child: padded),
    );
  }
}
