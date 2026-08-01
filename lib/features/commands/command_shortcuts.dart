/// 应用级快捷键层 — 从命令表自动生成键位绑定。
///
/// 挂在 MaterialApp.builder（Navigator 外层），任意焦点位置
/// （输入框、列表、无焦点）的按键都会沿焦点链冒泡到这里匹配命令；
/// Focus(autofocus) 仅在首次挂载时请求焦点，不会与输入框争抢。
library;

import 'package:flutter/material.dart';

import 'package:agent/features/commands/commands.dart';

class CommandShortcuts extends StatelessWidget {
  final Widget child;

  const CommandShortcuts({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        for (final cmd in AppCommands.all())
          if (cmd.shortcut != null) cmd.shortcut!: () => cmd.run(context),
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
