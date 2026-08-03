import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:signals_flutter/signals_flutter.dart';

import 'package:agent/rust_bridge/api/types.dart' as api;
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/dialog/app_dialog.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/field/inline_field.dart';
import 'package:agent/widgets/list/app_list.dart';
import 'package:agent/widgets/text/app_text.dart';

String _formatSessionTime(int timestampMs) {
  final now = DateTime.now();
  final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final diff = now.difference(date);

  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
  if (diff.inDays < 1) return '${diff.inHours} 小时前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  return '${date.month}/${date.day}';
}

/// 左侧面板 — 会话列表
///
/// 两级结构：主会话平铺，其子会话（子智能体创建，`parentSessionId` 非空）
/// 缩进显示在主会话下面，可展开/折叠（默认展开）。子会话同样支持
/// 点击切换、重命名与删除；删除主会话时由 Rust 侧级联删除其子会话。
class SessionList extends HookWidget {
  const SessionList({
    super.key,
    this.selectMode = false,
    this.selectedIds = const {},
    this.onSelectionChange,
  });

  /// 是否处于批量选择模式
  final bool selectMode;

  /// 当前已选中的会话 ID 集合
  final Set<String> selectedIds;

  /// 选中项变化时回调
  final ValueChanged<Set<String>>? onSelectionChange;

  @override
  Widget build(BuildContext context) {
    // 折叠的主会话 id 集合（默认全部展开）
    final collapsed = useState<Set<String>>(<String>{});

    // 加载会话列表
    useEffect(() {
      SessionStore.instance.loadSessions();
      return null;
    }, []);

    return SignalBuilder(
      builder: (context) {
        final mgr = SessionStore.instance;
        final sessions = mgr.sessionList.value;
        final loading = mgr.sessionListLoading.value;
        final selectedId = mgr.selectedId.value;
        final custom = CustomTheme.of(context);

        if (loading) {
          return const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (sessions.isEmpty) {
          return Center(
            child: AppText(
              '暂无会话',
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
            ),
          );
        }

        // 分组：主会话 + 各自子会话（均按更新时间倒序）
        final parents = sessions
            .where((s) => s.parentSessionId == null)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        final childrenByParent = <String, List<api.SessionInfo>>{};
        for (final s in sessions.where((s) => s.parentSessionId != null)) {
          childrenByParent.putIfAbsent(s.parentSessionId!, () => []).add(s);
        }
        for (final list in childrenByParent.values) {
          list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        }

        final items = <Widget>[];
        for (final parent in parents) {
          final children =
              childrenByParent[parent.id] ?? const <api.SessionInfo>[];
          items.add(
            _buildSessionItem(
              context: context,
              session: parent,
              selectedId: selectedId,
              selectMode: selectMode,
              selectedIds: selectedIds,
              onToggleSelection: _toggleSelection,
              expandable: children.isNotEmpty,
              collapsed: collapsed.value.contains(parent.id),
              onToggleExpand: () {
                final next = Set<String>.from(collapsed.value);
                if (!next.add(parent.id)) {
                  next.remove(parent.id);
                }
                collapsed.value = next;
              },
            ),
          );
          if (!collapsed.value.contains(parent.id)) {
            for (final child in children) {
              items.add(
                _buildSessionItem(
                  context: context,
                  session: child,
                  selectedId: selectedId,
                  selectMode: selectMode,
                  selectedIds: selectedIds,
                  onToggleSelection: _toggleSelection,
                  child: true,
                ),
              );
            }
          }
        }

        return SingleChildScrollView(
          child: AppList(
            size: AppListSize.small,
            containerPadding: EdgeInsets.zero,
            itemGap: 0,
            children: items,
          ),
        );
      },
    );
  }

  /// 构建单个会话列表项（主会话 / 子会话）。
  Widget _buildSessionItem({
    required BuildContext context,
    required api.SessionInfo session,
    required String? selectedId,
    required bool selectMode,
    required Set<String> selectedIds,
    required ValueChanged<String> onToggleSelection,
    bool child = false,
    bool expandable = false,
    bool collapsed = false,
    VoidCallback? onToggleExpand,
  }) {
    final custom = CustomTheme.of(context);
    final isSelected = session.id == selectedId;
    final isChecked = selectedIds.contains(session.id);

    final hoverActions = <Widget>[
      if (expandable)
        Transform.translate(
          offset: const Offset(0, -1),
          child: AppIconButton(
            icon: collapsed ? 'chevronRight' : 'chevronDown',
            size: ButtonSize.sm,
            hoverStyle: false,
            tooltip: collapsed ? '展开子任务' : '折叠子任务',
            onPressed: onToggleExpand,
          ),
        ),
      Transform.translate(
        offset: const Offset(0, -1),
        child: AppIconButton(
          icon: 'trash2',
          size: ButtonSize.sm,
          hoverStyle: false,
          tooltip: '删除会话',
          onPressed: () async {
            final confirmed = await AppDialog.show(
              context: context,
              title: '删除会话',
              child: AppText(
                '确定要删除「${session.name}」吗？此操作不可恢复。',
              ),
              onOk: () {},
            );
            if (confirmed == true) {
              await SessionStore.instance.deleteSessions([session.id]);
            }
          },
        ),
      ),
    ];

    return AppListItem(
      key: ValueKey(session.id),
      // 选择模式下显示复选框图标；子会话显示子任务图标
      icon: selectMode
          ? (isChecked ? 'checkSquare2' : 'square')
          : (child ? 'robot' : null),
      label: session.name,
      labelWidget: _SessionNameField(session: session),
      trailing: _formatSessionTime(session.updatedAt),
      active: selectMode ? isChecked : isSelected,
      intrinsicHeight: true,
      itemRadius: BorderRadius.zero,
      // 子会话缩进显示在主会话下面
      itemPadding: child
          ? EdgeInsets.only(
              left: 24 + custom.spacing.sm,
              right: custom.spacing.sm,
              top: custom.spacing.xs,
              bottom: custom.spacing.xs,
            )
          : null,
      onTap: selectMode
          ? () => onToggleSelection(session.id)
          : () {
              // 立即更新选中态，让 UI 先切换，不等待数据加载
              SessionStore.instance.selectedId.value = session.id;
              SessionStore.instance.switchTo(session.id);
            },
      // 选择模式下隐藏悬停操作按钮，避免干扰
      hoverActions: selectMode ? null : hoverActions,
    );
  }

  void _toggleSelection(String id) {
    final ids = Set<String>.from(selectedIds);
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }
    onSelectionChange?.call(ids);
  }
}

/// 会话名称编辑框 — 持有 [TextEditingController] 并随重命名结果同步。
///
/// 提取为独立 HookWidget，避免在 build 中内联创建 controller
/// （SignalBuilder 每次重建都会新建且永不释放）。
class _SessionNameField extends HookWidget {
  const _SessionNameField({required this.session});

  final api.SessionInfo session;

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: session.name);

    // 重命名成功后同步显示新名字；正在编辑时不覆盖用户输入
    useEffect(() {
      if (controller.text != session.name) {
        controller.text = session.name;
      }
      return null;
    }, [session.name]);

    return InlineField(
      controller: controller,
      size: FieldSize.sm,
      onSubmitted: (newName) async {
        if (newName.trim().isEmpty || newName.trim() == session.name) {
          return;
        }
        await SessionStore.instance.renameSession(session.id, newName.trim());
      },
    );
  }
}
