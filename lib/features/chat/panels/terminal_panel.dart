import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/terminal/terminal_tabs.dart';

/// 底部终端面板
class TerminalPanel extends StatelessWidget {
  const TerminalPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Container(
      color: custom.colors.bottomPanel,
      child: const TerminalTabs(),
    );
  }
}
