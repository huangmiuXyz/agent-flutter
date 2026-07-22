import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Scroll physics that completely eliminates any bounce/overscroll effect.
/// Overrides all relevant methods to ensure strict boundary clamping.
class _NoBounceScrollPhysics extends ScrollPhysics {
  const _NoBounceScrollPhysics({super.parent});

  @override
  _NoBounceScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _NoBounceScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Strict clamping: never allow going past boundaries
    if (value < position.minScrollExtent) {
      return value - position.minScrollExtent;
    }
    if (value > position.maxScrollExtent) {
      return value - position.maxScrollExtent;
    }
    return 0.0;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // No ballistic scrolling at all — stops immediately
    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}

class ChatFleather extends StatefulWidget {
  const ChatFleather({super.key, this.controller});

  /// 外部传入的 controller，为空则内部自动创建
  final FleatherController? controller;

  @override
  State<ChatFleather> createState() => _ChatFleatherState();
}

class _ChatFleatherState extends State<ChatFleather> {
  late FleatherController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? FleatherController();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    // Rebuild to show/hide placeholder.
    setState(() {});
  }

  bool get _isEmpty =>
      _controller.document.toPlainText().replaceAll('\n', '').isEmpty;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: custom.spacing.sm),
      child: FleatherTheme(
        data: FleatherThemeData.fallback(context).copyWith(
          strutStyle: StrutStyle(
            forceStrutHeight: true,
            fontSize: custom.typography.bodySize,
          ),
        ),
        child: Builder(
          builder: (context) {
            // Read paragraph spacing from the Fleather theme so the placeholder
            // aligns with where the editor actually renders its first line.
            final fleatherTheme = FleatherTheme.of(context)!;
            final paragraphTop = fleatherTheme.paragraph.spacing.top;
            return Stack(
              children: [
                ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    overscroll: false,
                    physics: const _NoBounceScrollPhysics(),
                  ),
                  child: FleatherEditor(
                    controller: _controller,
                    focusNode: _focusNode,
                    expands: true,
                    scrollPhysics: const _NoBounceScrollPhysics(),
                  ),
                ),
                // Placeholder shown when content is empty
                if (_isEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Padding(
                        padding: EdgeInsets.only(top: paragraphTop),
                        child: AppText(
                          '输入消息...',
                          variant: AppTextVariant.body,
                          color: custom.colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
