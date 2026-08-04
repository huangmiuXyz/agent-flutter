import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/theme/fleather_utils.dart';
import 'package:agent/utils/ime_composing_tracker.dart';
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
  const ChatFleather({
    super.key,
    this.controller,
    this.focusNode,
    this.onSubmit,
  });

  /// 外部传入的 controller，为空则内部自动创建
  final FleatherController? controller;

  /// 外部传入的 FocusNode（用于外部聚焦控制），为空则内部自动创建
  final FocusNode? focusNode;

  /// 按下 Enter 时回调（不含 Shift 修饰键）
  final VoidCallback? onSubmit;

  @override
  State<ChatFleather> createState() => _ChatFleatherState();
}

class _ChatFleatherState extends State<ChatFleather> {
  late FleatherController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? FleatherController();
    _controller.addListener(_onControllerChanged);
    // 外部传入的 FocusNode 由外部负责 dispose，内部创建的由自己 dispose
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    // Rebuild to show/hide placeholder.
    setState(() {});
  }

  bool get _isEmpty =>
      _controller.document.toPlainText().replaceAll('\n', '').isEmpty;

  /// 处理 Enter：无修饰键时触发发送；
  /// 输入法组合中放行按键（不发送），让 IME 提交组合内容落下。
  /// 注意必须返回 ignored：若消费按键，Windows 引擎会跳过
  /// 键盘消息翻译链，组合内容无法提交。
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      // 带修饰键的 Enter（如 Shift+Enter 换行）不拦截
      return KeyEventResult.ignored;
    }
    if (ImeComposingTracker.instance.isComposing) {
      // 输入法组合中：不触发发送，把 Enter 留给 IME 提交组合内容
      return KeyEventResult.ignored;
    }
    widget.onSubmit?.call();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: custom.spacing.sm),
      child: FleatherTheme(
        data: buildFleatherTheme(
          context,
          fontFamily: custom.typography.fontFamily,
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
                    child: Focus(
                      onKeyEvent: _onKeyEvent,
                      child: FleatherEditor(
                        controller: _controller,
                        focusNode: _focusNode,
                        expands: true,
                        scrollPhysics: const _NoBounceScrollPhysics(),
                      ),
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


