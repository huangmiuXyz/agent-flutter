import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/store/xterm_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/text/app_text.dart';

class ExecutePanel extends HookWidget {
  const ExecutePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController();
    final output = useState('');
    final running = useState(false);
    final custom = CustomTheme.of(context);

    void sendSigint() {
      final ids = XtermStore.instance.activeIds.value;
      if (ids.isEmpty) return;
      XtermStore.instance.forId(ids.first).sendInput('\x03');
    }

    Future<void> execute() async {
      final cmd = controller.text.trim();
      if (cmd.isEmpty) return;

      running.value = true;
      output.value = '';

      try {
        final ids = XtermStore.instance.activeIds.value;
        if (ids.isEmpty) {
          output.value = '[error: no active terminal]';
          return;
        }

        final id = ids.first;
        final result = await XtermStore.instance.forId(id).execute(cmd);
        if (context.mounted) output.value = result;
      } catch (e) {
        if (context.mounted) output.value = '[error: $e]';
      } finally {
        if (context.mounted) running.value = false;
      }
    }

    return Container(
      color: custom.colors.panelElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 1, color: custom.colors.selected),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: custom.spacing.sm,
              vertical: custom.spacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: CallbackShortcuts(
                    bindings: {
                      SingleActivator(LogicalKeyboardKey.enter, control: true):
                          execute,
                    },
                    child: Focus(
                      child: TextField(
                        controller: controller,
                        enabled: !running.value,
                        maxLines: 4,
                        minLines: 1,
                        style: TextStyle(
                          fontSize: custom.typography.captionSize,
                          color: custom.colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: custom.spacing.sm,
                            vertical: custom.spacing.xs,
                          ),
                          hintText: '输入命令... (Ctrl+Enter 执行)',
                          hintStyle: TextStyle(
                            color: custom.colors.textSecondary,
                            fontSize: custom.typography.captionSize,
                          ),
                          filled: true,
                          fillColor: custom.colors.panel,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              custom.radii.sm.topLeft.x,
                            ),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: custom.spacing.sm),
                AppPrimaryButton(
                  icon: 'square',
                  text: 'Ctrl+C',
                  onPressed: sendSigint,
                  style: ButtonStyle(visualDensity: VisualDensity.compact),
                ),
                SizedBox(width: custom.spacing.sm),
                AppPrimaryButton(
                  text: '执行',
                  disabled: running.value,
                  onPressed: execute,
                  style: ButtonStyle(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: custom.colors.panel,
              padding: EdgeInsets.all(custom.spacing.sm),
              child: switch ((output.value, running.value)) {
                (final out, false) when out.isEmpty => Center(
                  child: AppText(
                    '输入命令后点击执行',
                    variant: AppTextVariant.caption,
                    color: custom.colors.textSecondary,
                  ),
                ),
                (final out, final run) => SingleChildScrollView(
                  child: SelectableText(
                    run ? '运行中... $out' : out,
                    style: TextStyle(
                      fontSize: custom.typography.captionSize,
                      color: custom.colors.textPrimary,
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
