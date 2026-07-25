import 'package:flutter/material.dart';
import 'package:agent/features/chat/panels/session_list.dart';
import 'package:agent/store/config_store.dart';
import 'package:agent/store/llm_store.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 左侧面板 — 会话列表
class LeftPanel extends StatelessWidget {
  const LeftPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return Container(
      color: custom.colors.panel,
      child: Column(
        children: [
          // ── Header toolbar ──
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: custom.spacing.sm,
              vertical: custom.spacing.xs,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: custom.colors.separator),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppText(
                    '对话',
                    variant: AppTextVariant.body,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                AppIconButton(
                  icon: 'plus',
                  size: ButtonSize.sm,
                  onPressed: () => _createSession(context),
                ),
              ],
            ),
          ),
          // ── Session list ──
          Expanded(child: const SessionList()),
        ],
      ),
    );
  }

  Future<void> _createSession(BuildContext context) async {
    try {
      final sessionId = await SessionStore.instance.createSession(
        service: LlmStore.instance.service,
        dbPath: ConfigStore.instance.dbPath,
      );
      // createSession 已设置 selectedId，switchTo 异步加载数据不阻塞
      SessionStore.instance.switchTo(
        sessionId,
        service: LlmStore.instance.service,
        dbPath: ConfigStore.instance.dbPath,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('创建失败: $e')));
      }
    }
  }
}
