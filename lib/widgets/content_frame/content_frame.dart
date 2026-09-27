import 'package:flutter/material.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/utils/layout_utils.dart' show readingWidthFor;
import 'package:agent/utils/platform.dart';

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

  /// 页顶内边距覆盖值；为空时按平台取默认：桌面端用 `spacing.pageTop`
  /// （为弹窗标题预留空间），移动端用紧凑间距避免顶部过空。
  final double? topPadding;

  const ContentFrame({
    super.key,
    required this.child,
    this.scrollable = true,
    this.topPadding,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = CustomTheme.of(context).spacing;

    // 桌面弹窗顶部需为标题栏让位（pageTop=70）；移动端页面顶部已有导航
    // /Tab 行，若沿用同样间距会出现过大的空白，改用紧凑间距。
    final topPadding = this.topPadding ??
        (isMobilePlatform ? spacing.md : spacing.pageTop);

    final padded = Padding(
      padding: EdgeInsets.only(
        top: topPadding,
        bottom: spacing.sm,
        left: spacing.edgeMargin,
        right: spacing.edgeMargin,
      ),
      child: SizedBox(width: readingWidthFor(context), child: child),
    );

    // Always keep the same widget structure: toggling [scrollable] must not
    // destroy the subtree (which would lose TextField focus, scroll position,
    // etc. when a page flips between virtualized and static content).
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final body = scrollable ? SingleChildScrollView(child: padded) : padded;
        // Pass through bounded height so inner [Expanded] / [ListView.builder]
        // can virtualize. Without this, [Align] with loose constraints would
        // make the child measure itself, losing the viewport height.
        //
        // Only the height is forced: forcing the width would defeat [Align]'s
        // horizontal centering of the reading-width content (the Padding would
        // fill the full width and pin its child to the left edge).
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : null,
            child: body,
          ),
        );
      },
    );
  }
}
