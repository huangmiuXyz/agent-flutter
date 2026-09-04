/// 工具开关 — 显示在聊天输入框工具栏（图片上传按钮右侧）。
///
/// 点击切换 [SessionStore.enableTools]：
/// - 开启（默认）：发送消息时把工具定义传给 AI，可调用工具
/// - 关闭：纯对话模式，后端不传任何工具定义
library;

import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:agent/store/session_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';

class ToolToggle extends StatelessWidget {
  const ToolToggle({super.key, this.size = ButtonSize.sm});

  final ButtonSize size;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return SignalBuilder(
      builder: (_) {
        final enabled = SessionStore.instance.enableTools.value;
        return AppIconButton(
          icon: 'wrench',
          size: size,
          tooltip: enabled ? '工具已启用（点击禁用为纯对话）' : '工具已禁用（点击启用）',
          backgroundColor: enabled ? custom.colors.hover : null,
          iconColor:
              enabled ? custom.colors.textPrimary : custom.colors.textDisabled,
          onPressed: () {
            SessionStore.instance.enableTools.value = !enabled;
          },
        );
      },
    );
  }
}
