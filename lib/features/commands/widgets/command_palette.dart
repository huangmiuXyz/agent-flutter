/// 命令面板 — VSCode 风格的命令搜索与执行入口。
///
/// 全部基于现有组件拼装：AppDialog（顶部对齐弹窗）+ AppField（搜索框）
/// + AppList/AppListGroup/AppListItem（分组列表）。键盘操作：
/// - ↑/↓ 移动选中（AppList 全局键盘导航，搜索框聚焦时同样生效）
/// - Enter 执行选中命令（不可用的命令灰显、不响应）
/// - Esc 关闭面板
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/commands/command_store.dart';
import 'package:agent/features/commands/models/command_info.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/dialog/app_dialog.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/list/app_list.dart';

/// 打开命令面板（顶部对齐的模态弹窗，无标题栏）。
Future<void> showCommandPalette(BuildContext context) {
  return AppDialog.show(
    context: context,
    title: null,
    showFooter: false,
    showCancel: false,
    width: 560,
    alignment: Alignment.topCenter,
    bodyPadding: EdgeInsets.zero,
    child: const Padding(
      padding: EdgeInsets.only(top: 72),
      child: CommandPalette(),
    ),
  );
}

/// 命令面板主体：搜索框 + 分组列表 + 键盘执行。
class CommandPalette extends HookWidget {
  const CommandPalette({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final searchController = useTextEditingController();
    final query = useState('');

    // 订阅影响命令可用性的信号：流式状态/选中会话变化时刷新 enabled
    useExistingSignal(SessionStore.instance.streamingSessionIds);
    useExistingSignal(SessionStore.instance.selectedId);

    final commands = useMemoized(
      () => CommandStore.instance.query(query.value),
      [query.value],
    );

    // 按 category 分组（保持注册顺序；无 category 的组不显示标题）
    final groups = <String?, List<CommandInfo>>{};
    for (final c in commands) {
      groups.putIfAbsent(c.category, () => []).add(c);
    }

    void execute(CommandInfo c) {
      // 先执行再关闭：run 中可能打开新弹窗（如设置），此时 context 仍有效
      c.run(context);
      Navigator.of(context).pop();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 搜索框 ──
        Padding(
          padding: EdgeInsets.fromLTRB(
            custom.spacing.md,
            custom.spacing.sm,
            custom.spacing.md,
            custom.spacing.xs,
          ),
          child: Focus(
            onKeyEvent: (node, event) {
              // Esc 关闭面板（AppList 的键盘导航不消费 Esc）
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.of(context).pop();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: AppField(
              controller: searchController,
              placeholder: '输入命令名称…',
              icon: 'search',
              size: FieldSize.md,
              onChanged: (v) => query.value = v,
            ),
          ),
        ),

        // ── 命令列表 ──
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: 240,
            maxHeight: MediaQuery.of(context).size.height * 0.55,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: custom.spacing.xs),
            child: AppList(
              size: AppListSize.small,
              keyboardNavigable: true,
              // 打开即选中第一项，Enter 可直接执行
              initialFocusedIndex: 0,
              emptyPlaceholder: '无匹配命令',
              children: [
                for (final entry in groups.entries)
                  AppListGroup(
                    title: entry.key,
                    children: [
                      for (final c in entry.value)
                        AppListItem(
                          icon: c.icon,
                          label: c.title,
                          trailing: c.shortcut != null
                              ? formatShortcut(c.shortcut!)
                              : null,
                          disabled: !c.isEnabled,
                          onTap: c.isEnabled ? () => execute(c) : null,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
