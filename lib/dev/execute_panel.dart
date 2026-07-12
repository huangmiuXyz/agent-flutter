import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_button.dart';
import 'package:agent/widgets/text/app_text.dart';
import 'package:agent/widgets/terminal/xterm_provider.dart';

class ExecutePanel extends HookConsumerWidget {
  const ExecutePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final output = useState('');
    final running = useState(false);
    final custom = CustomTheme.of(context);

    void sendSigint() {
      final registry = ref.read(xtermRegistryProvider);
      final ids = registry.ids.toList();
      if (ids.isEmpty) return;
      ref.read(xtermManagerProvider(ids.first).notifier).sendInput('\x03');
    }

    Future<void> execute() async {
      final cmd = controller.text.trim();
      if (cmd.isEmpty) return;

      running.value = true;
      output.value = '';

      try {
        final registry = ref.read(xtermRegistryProvider);
        final ids = registry.ids.toList();
        if (ids.isEmpty) {
          output.value = '[error: no active terminal]';
          return;
        }

        final id = ids.first;
        final result = await ref
            .read(xtermManagerProvider(id).notifier)
            .execute(cmd);
        output.value = result;
      } catch (e) {
        output.value = '[error: $e]';
      } finally {
        if (context.mounted) running.value = false;
      }
    }

    return Container(
      color: custom.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 1, color: custom.surfaceContainerHighest),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: custom.spacingSm,
              vertical: custom.spacingXs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: CallbackShortcuts(
                    bindings: {
                      SingleActivator(
                        LogicalKeyboardKey.enter,
                        control: true,
                      ): execute,
                    },
                    child: Focus(
                      child: TextField(
                        controller: controller,
                        enabled: !running.value,
                        maxLines: 4,
                        minLines: 1,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: custom.fontSizeCaption,
                          color: custom.onSurface,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: custom.spacingSm,
                            vertical: custom.spacingXs,
                          ),
                          hintText: '输入命令... (Ctrl+Enter 执行)',
                          hintStyle: TextStyle(
                            color: custom.onSurfaceVariant,
                            fontSize: custom.fontSizeCaption,
                          ),
                          filled: true,
                          fillColor: custom.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(custom.radiusSm.topLeft.x),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: custom.spacingSm),
                AppButton(
                  icon: 'square',
                  text: 'Ctrl+C',
                  onPressed: sendSigint,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                SizedBox(width: custom.spacingSm),
                AppButton(
                  text: '执行',
                  disabled: running.value,
                  onPressed: execute,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: custom.surfaceContainerLow,
              padding: EdgeInsets.all(custom.spacingSm),
              child: switch ((output.value, running.value)) {
                (final out, false) when out.isEmpty =>
                  Center(
                    child: AppText(
                      '输入命令后点击执行',
                      variant: AppTextVariant.caption,
                      color: custom.onSurfaceVariant,
                    ),
                  ),
                (final out, final run) =>
                  SingleChildScrollView(
                    child: SelectableText(
                      run ? '运行中... $out' : out,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: custom.fontSizeCaption,
                        color: custom.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }
}
