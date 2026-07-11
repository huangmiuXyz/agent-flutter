import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_button.dart';
import 'package:agent/widgets/text/app_text.dart';
import 'package:agent/widgets/terminal/provider.dart';

class ExecutePanel extends ConsumerStatefulWidget {
  const ExecutePanel({super.key});

  @override
  ConsumerState<ExecutePanel> createState() => _ExecutePanelState();
}

class _ExecutePanelState extends ConsumerState<ExecutePanel> {
  final _controller = TextEditingController();
  final _output = ValueNotifier<String>('');
  bool _running = false;

  @override
  void dispose() {
    _controller.dispose();
    _output.dispose();
    super.dispose();
  }

  Future<void> _execute() async {
    final cmd = _controller.text.trim();
    if (cmd.isEmpty) return;

    setState(() => _running = true);
    _output.value = '';

    try {
      // 获取第一个活跃终端
      final registry = ref.read(terminalRegistryProvider);
      final ids = registry.ids.toList();
      if (ids.isEmpty) {
        _output.value = '[error: no active terminal]';
        return;
      }

      final id = ids.first;
      final result = await ref
          .read(terminalManagerProvider(id).notifier)
          .execute(cmd);
      _output.value = result;
    } catch (e) {
      _output.value = '[error: $e]';
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

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
                  child: TextField(
                    controller: _controller,
                    enabled: !_running,
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
                      hintText: '输入命令...',
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
                    onSubmitted: (_) => _execute(),
                  ),
                ),
                SizedBox(width: custom.spacingSm),
                AppButton(
                  text: '执行',
                  disabled: _running,
                  onPressed: _execute,
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
              child: ValueListenableBuilder<String>(
                valueListenable: _output,
                builder: (context, output, _) {
                  if (output.isEmpty && !_running) {
                    return Center(
                      child: AppText(
                        '输入命令后点击执行',
                        variant: AppTextVariant.caption,
                        color: custom.onSurfaceVariant,
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    child: SelectableText(
                      _running ? '运行中... $output' : output,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: custom.fontSizeCaption,
                        color: custom.onSurface,
                        height: 1.4,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
