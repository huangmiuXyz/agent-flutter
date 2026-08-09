/// 检查点视图左侧 — 路径列表
///
/// 展示所有出现过的 work_dir（含检查点数），点击切换右侧检查点列表。
/// 默认由 [CheckpointStore.refreshAll] 选中第一个路径。
/// 支持批量选择与删除（样式与聊天会话列表一致）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/rust_bridge/api/types.dart' as api_types;
import 'package:agent/store/checkpoint_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/dialog/app_dialog.dart';
import 'package:agent/widgets/list/app_list.dart';
import 'package:agent/widgets/text/app_text.dart';

class CheckpointPathList extends HookWidget {
  const CheckpointPathList({
    super.key,
    this.selectMode = false,
    this.selectedIds = const {},
    this.onSelectionChange,
  });

  /// 是否处于批量选择模式
  final bool selectMode;

  /// 当前已选中的路径集合
  final Set<String> selectedIds;

  /// 选中项变化时回调
  final ValueChanged<Set<String>>? onSelectionChange;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final paths = useExistingSignal(CheckpointStore.instance.paths);
    final current = useExistingSignal(CheckpointStore.instance.currentWorkDir);

    if (paths.value.isEmpty) {
      return Center(
        child: AppText(
          '暂无检查点',
          variant: AppTextVariant.caption,
          color: custom.colors.textSecondary,
        ),
      );
    }

    return SingleChildScrollView(
      child: AppList(
        size: AppListSize.small,
        containerPadding: EdgeInsets.zero,
        itemGap: 0,
        children: [
          for (final p in paths.value)
            _buildPathItem(context, custom, p, current.value),
        ],
      ),
    );
  }

  /// 单个路径项：样式与聊天会话列表一致（多选图标 / hover 删除）。
  Widget _buildPathItem(
    BuildContext context,
    CustomTheme custom,
    api_types.CheckpointPathInfo p,
    String? current,
  ) {
    final isChecked = selectedIds.contains(p.workDir);
    final isActive = selectMode ? isChecked : current == p.workDir;

    return AppListItem(
      key: ValueKey(p.workDir),
      // 选择模式下显示复选框图标；与聊天会话列表一致
      icon: selectMode ? (isChecked ? 'checkSquare2' : 'square') : null,
      label: _pathName(p.workDir),
      trailing: '${p.checkpointCount}',
      active: isActive,
      intrinsicHeight: true,
      itemRadius: BorderRadius.zero,
      onTap: selectMode
          ? () {
              final ids = Set<String>.from(selectedIds);
              if (!ids.add(p.workDir)) {
                ids.remove(p.workDir);
              }
              onSelectionChange?.call(ids);
            }
          : () => CheckpointStore.instance.selectWorkDir(p.workDir),
      // 选择模式下隐藏悬停操作按钮，避免干扰（与聊天列表一致）
      hoverActions: selectMode ? null : [_deleteButton(context, custom, p)],
    );
  }

  /// hover 删除按钮：删除该路径下所有检查点记录（不影响 git 仓库）。
  Widget _deleteButton(
    BuildContext context,
    CustomTheme custom,
    api_types.CheckpointPathInfo p,
  ) {
    return Transform.translate(
      offset: const Offset(0, -1),
      child: AppIconButton(
        icon: 'trash2',
        size: ButtonSize.sm,
        hoverStyle: false,
        tooltip: '删除检查点路径',
        onPressed: () async {
          final confirmed = await AppDialog.show(
            context: context,
            title: '删除检查点路径',
            child: AppText(
              '确定要删除「${_pathName(p.workDir)}」下的所有检查点记录吗？\n'
              '此操作不可恢复，但不会影响 git 仓库与聊天记录。',
            ),
            onOk: () {},
          );
          if (confirmed == true) {
            await CheckpointStore.instance.deletePaths([p.workDir]);
          }
        },
      ),
    );
  }

  /// 路径显示：完整路径太长，取最后两段（项目名/目录名）。
  String _pathName(String workDir) {
    final normalized = workDir.replaceAll('\\', '/');
    final parts = normalized.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.length <= 2) return workDir;
    return '${parts[parts.length - 2]}/${parts.last}';
  }
}
