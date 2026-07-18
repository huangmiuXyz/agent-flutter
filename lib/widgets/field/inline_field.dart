import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/field/app_field.dart';

/// An inline-editable text field that displays as static text until
/// double-tapped, then switches to an editable [TextField].
///
/// Designed for inline renaming, tag editing, or any scenario where
/// you want a compact read → edit → commit flow.
class InlineField extends HookWidget {
  final String? placeholder;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final FieldSize size;

  const InlineField({
    super.key,
    this.placeholder,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.size = FieldSize.md,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final internalController = useMemoized(() => TextEditingController());
    final textController = controller ?? internalController;
    final focusNode = useMemoized(() => FocusNode());
    final lastTapTime = useRef<DateTime?>(null);
    final isEditing = useState(false);

    // Select all when focus is gained in edit mode
    useEffect(() {
      void listener() {
        if (focusNode.hasFocus && isEditing.value) {
          textController.value = textController.value.copyWith(
            selection: TextSelection(
              baseOffset: 0,
              extentOffset: textController.text.length,
            ),
          );
        }
      }

      focusNode.addListener(listener);
      return () => focusNode.removeListener(listener);
    }, []);

    // Commit on focus loss
    useEffect(() {
      void listener() {
        if (!focusNode.hasFocus && isEditing.value) {
          onSubmitted?.call(textController.text);
          isEditing.value = false;
        }
      }

      focusNode.addListener(listener);
      return () => focusNode.removeListener(listener);
    }, []);

    final fontSize = switch (size) {
      FieldSize.sm => custom.typography.captionSize,
      FieldSize.md => custom.typography.bodySize,
      FieldSize.lg => custom.typography.subtitleSize,
    };

    // Use height: 1.0 so line-height equals fontSize exactly,
    // preventing font metrics from pushing the cursor up.
    final textStyle = custom.typography
        .styleForSize(
          fontSize,
          custom.colors.textPrimary,
          weight: custom.typography.bodyWeight,
        )
        .copyWith(height: 1.0);

    if (!isEditing.value) {
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: enabled
            ? (event) {
                final now = DateTime.now();
                final last = lastTapTime.value;
                lastTapTime.value = now;
                if (last != null && now.difference(last).inMilliseconds < 300) {
                  textController.value = textController.value.copyWith(
                    selection: TextSelection(
                      baseOffset: 0,
                      extentOffset: textController.text.length,
                    ),
                  );
                  isEditing.value = true;
                }
              }
            : null,
        child: IntrinsicWidth(
          child: IgnorePointer(
            ignoring: true,
            child: TextField(
              key: const ValueKey('inline_display'),
              controller: textController,
              readOnly: true,
              showCursor: false,
              style: textStyle,
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: textStyle.copyWith(
                  color: custom.colors.textDisabled,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
        ),
      );
    }

    return IntrinsicWidth(
      child: TextField(
        key: const ValueKey('inline_edit'),
        controller: textController,
        focusNode: focusNode,
        autofocus: true,
        style: textStyle,
        cursorColor: custom.colors.accent,
        textInputAction: TextInputAction.done,
        onChanged: onChanged,
        onSubmitted: (value) {
          onSubmitted?.call(value);
          isEditing.value = false;
        },
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: textStyle.copyWith(color: custom.colors.textDisabled),
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }
}
