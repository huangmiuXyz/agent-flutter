/// 命令面板 — VSCode 风格的命令搜索与执行入口。
///
/// 以 [AppDialog] 弹窗呈现：顶部搜索框（autofocus），下方命令列表
/// 按 category 分组。键盘操作：
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
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/list/app_list.dart';

/// 打开命令面板（模态弹窗）。
Future<void> showCommandPalette(BuildContext context) {
  return AppDialog.show(
    context: context,
    title: '命令面板',
    showFooter: false,
    showCancel: false,
    width: 520,
    compactHeader: true,
    bodyPadding: EdgeInsets.zero,
    child: const CommandPalette(),
  );
}

/// 命令面板主体：搜索 + 分组列表 + 键盘执行。
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
        Focus(
          onKeyEvent: (node, event) {
            // Esc 关闭面板（AppList 的键盘导航不消费 Esc）
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: custom.spacing.md,
              vertical: custom.spacing.xs,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: custom.colors.border),
              ),
            ),
            child: TextField(
              controller: searchController,
              autofocus: true,
              onChanged: (v) => query.value = v,
              style: TextStyle(
                fontSize: custom.typography.bodySize,
                fontFamily: custom.typography.fontFamily,
                color: custom.colors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '输入命令名称…',
                hintStyle: TextStyle(
                  fontSize: custom.typography.bodySize,
                  color: custom.colors.textSecondary,
                ),
                prefixIcon: AppIcon(
                  'search',
                  size: custom.typography.bodySize,
                  color: custom.colors.textSecondary,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
        ),

        // ── 命令列表 ──
        Flexible(
          child: SingleChildScrollView(
            child: AppList(
              size: AppListSize.small,
              keyboardNavigable: true,
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
