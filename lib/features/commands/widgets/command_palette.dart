/// 命令面板 — VSCode 风格的命令搜索与执行入口。
///
/// 以 [ContextMenu] 同款的 OverlayEntry 模式呈现（顶部居中、半透明遮罩），
/// 面板视觉复用 AppCard 的 menu 风格（menuBackground/细边框/小圆角/阴影），
/// 搜索条为扁平无边框输入，列表复用 AppList 键盘导航。交互：
/// - 输入即过滤，↑/↓ 移动选中，Enter 执行（禁用命令灰显、不响应）
/// - Esc 或点击遮罩关闭
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/commands/command_store.dart';
import 'package:agent/features/commands/models/command_info.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/card/app_card.dart';
import 'package:agent/widgets/divider/app_divider.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/list/app_list.dart';

/// 打开命令面板（OverlayEntry，顶部居中）。
void showCommandPalette(BuildContext context) {
  // 入口 context 可能是根 Navigator（快捷键层，其自身没有 Overlay 祖先），
  // 统一从 Navigator 取它管理的 overlay
  final overlay = Navigator.of(context).overlay;
  if (overlay == null) return;

  // 已打开时忽略重复触发（避免嵌套面板）
  if (_paletteOpen) return;
  _paletteOpen = true;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CommandPaletteOverlay(
      onClose: () {
        _paletteOpen = false;
        entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

/// 面板是否已打开（防重复触发）。
bool _paletteOpen = false;

/// 命令面板覆盖层：半透明遮罩（点按关闭）+ 顶部居中面板。
class _CommandPaletteOverlay extends HookWidget {
  final VoidCallback onClose;

  const _CommandPaletteOverlay({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Stack(
      children: [
        // 全屏遮罩：点击关闭面板
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => onClose(),
            child: Container(color: custom.colors.overlay),
          ),
        ),
        // 顶部居中的面板（轻微淡入）
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: 72),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 120),
              builder: (_, value, child) =>
                  Opacity(opacity: value, child: child),
              child: _CommandPalette(onClose: onClose),
            ),
          ),
        ),
      ],
    );
  }
}

/// 命令面板主体：搜索条 + 分组命令列表。
class _CommandPalette extends HookWidget {
  final VoidCallback onClose;

  const _CommandPalette({required this.onClose});

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
      c.run(context);
      onClose();
    }

    return AppCard(
      scrollable: false,
      padding: EdgeInsets.zero,
      backgroundColor: custom.colors.menuBackground,
      border: Border.all(color: custom.colors.menuBorder, width: 1),
      borderRadius: custom.radii.sm,
      boxShadow: custom.shadows.large,
      child: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 搜索条（扁平无边框） ──
            Focus(
              onKeyEvent: (node, event) {
                // Esc 关闭面板（AppList 的键盘导航不消费 Esc）
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  onClose();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  custom.spacing.md,
                  custom.spacing.sm,
                  custom.spacing.md,
                  custom.spacing.sm,
                ),
                child: Row(
                  children: [
                    AppIcon(
                      'search',
                      size: 16,
                      color: custom.colors.textSecondary,
                    ),
                    SizedBox(width: custom.spacing.sm),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        onChanged: (v) => query.value = v,
                        style: TextStyle(
                          fontSize: 15,
                          fontFamily: custom.typography.fontFamily,
                          color: custom.colors.textPrimary,
                        ),
                        cursorColor: custom.colors.textPrimary,
                        decoration: InputDecoration(
                          hintText: '输入命令名称…',
                          hintStyle: TextStyle(
                            fontSize: 15,
                            color: custom.colors.textSecondary,
                          ),
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppDivider(size: AppDividerSize.small),

            // ── 命令列表 ──
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 240,
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(vertical: custom.spacing.xs),
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
        ),
      ),
    );
  }
}
