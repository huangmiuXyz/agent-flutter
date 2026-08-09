import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/chat/panels/session_list.dart';
import 'package:agent/features/checkpoints/checkpoint_path_list.dart';
import 'package:agent/store/checkpoint_store.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/dialog/app_dialog.dart';
import 'package:agent/widgets/tab/app_tab_bar.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 左侧面板 — 会话列表（支持批量选择与删除）
class LeftPanel extends HookWidget {
  const LeftPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final selectMode = useSignal(false);
    final selectedIds = useSignal(<String>{});
    final isHeaderHovered = useState(false);
    // 面板模式：false = 对话；true = 检查点
    final isCheckpointMode = useExistingSignal(
      CheckpointStore.instance.activeMode,
    );

    // 退出选择模式时清理选中状态
    useEffect(() {
      if (!selectMode.value) {
        selectedIds.value = {};
      }
      return null;
    }, [selectMode.value]);

    return Container(
      color: custom.colors.panel,
      child: Column(
        children: [
          // ── 模式 Tab：对话 / 检查点 ──
          Padding(
            padding: EdgeInsets.fromLTRB(
              custom.spacing.sm,
              custom.spacing.xs,
              custom.spacing.sm,
              0,
            ),
            child: AppTabBar(
              tabs: const ['对话', '检查点'],
              activeIndex: isCheckpointMode.value ? 1 : 0,
              size: TabBarSize.sm,
              onChanged: (i) {
                // 切换模式时退出批量选择状态
                selectMode.value = false;
                if (i == 1) {
                  CheckpointStore.instance.switchToCheckpoints();
                } else {
                  CheckpointStore.instance.switchToChat();
                }
              },
            ),
          ),
          // ── 标题区（两种模式都显示，样式与聊天一致） ──
          MouseRegion(
            onEnter: (_) => isHeaderHovered.value = true,
            onExit: (_) => isHeaderHovered.value = false,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: custom.spacing.sm,
                vertical: custom.spacing.xs,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: custom.colors.separator),
                ),
              ),
              child: _buildHeader(
                context,
                custom,
                selectMode,
                selectedIds,
                isHeaderHovered.value,
                isCheckpointMode.value,
              ),
            ),
          ),
          // ── 内容区：会话列表 / 检查点路径列表（两种模式都显示） ──
          Expanded(
            child: isCheckpointMode.value
                ? CheckpointPathList(
                    selectMode: selectMode.value,
                    selectedIds: selectedIds.value,
                    onSelectionChange: (ids) {
                      selectedIds.value = ids;
                    },
                  )
                : SessionList(
                    selectMode: selectMode.value,
                    selectedIds: selectedIds.value,
                    onSelectionChange: (ids) {
                      selectedIds.value = ids;
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    CustomTheme custom,
    Signal<bool> selectMode,
    Signal<Set<String>> selectedIds,
    bool headerHovered,
    bool isCheckpointMode,
  ) {
    if (selectMode.value) {
      return Row(
        children: [
          Expanded(
            child: AppText(
              selectedIds.value.isEmpty
                  ? (isCheckpointMode ? '选择检查点路径' : '选择会话')
                  : '已选 ${selectedIds.value.length} 项',
              variant: AppTextVariant.body,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (selectedIds.value.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(right: custom.spacing.xs),
              child: AppIconButton(
                icon: 'trash2',
                size: ButtonSize.sm,
                backgroundColor: custom.colors.danger,
                tooltip: '删除选中',
                onPressed: () => isCheckpointMode
                    ? _batchDeleteCheckpoints(context, selectMode, selectedIds)
                    : _batchDelete(context, selectMode, selectedIds),
              ),
            ),
          AppIconButton(
            icon: 'x',
            size: ButtonSize.sm,
            tooltip: '退出选择',
            onPressed: () {
              selectMode.value = false;
            },
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: AppText(
            isCheckpointMode ? '检查点' : '对话',
            variant: AppTextVariant.body,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        // 批量选择按钮：仅悬停 header 时显示
        AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: headerHovered ? 1.0 : 0.0,
          child: AppIconButton(
            icon: 'checkSquare2',
            size: ButtonSize.sm,
            tooltip: '批量选择',
            onPressed: () {
              selectMode.value = true;
            },
          ),
        ),
        if (!isCheckpointMode)
          AppIconButton(
            icon: 'plus',
            size: ButtonSize.sm,
            onPressed: () => _createSession(context),
          ),
      ],
    );
  }

  Future<void> _batchDeleteCheckpoints(
    BuildContext context,
    Signal<bool> selectMode,
    Signal<Set<String>> selectedIds,
  ) async {
    final ids = List<String>.from(selectedIds.value);
    final confirmed = await AppDialog.show(
      context: context,
      title: '删除检查点路径',
      child: AppText(
        '确定要删除选中的 ${ids.length} 个路径下的所有检查点记录吗？\n'
        '此操作不可恢复，但不会影响 git 仓库与聊天记录。',
      ),
      onOk: () {},
    );
    if (confirmed != true) {
      selectMode.value = false;
      return;
    }

    final ok = await CheckpointStore.instance.deletePaths(ids);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('删除失败')));
    }
    selectMode.value = false;
  }

  Future<void> _batchDelete(
    BuildContext context,
    Signal<bool> selectMode,
    Signal<Set<String>> selectedIds,
  ) async {
    final ids = List<String>.from(selectedIds.value);
    final confirmed = await AppDialog.show(
      context: context,
      title: '删除会话',
      child: AppText('确定要删除选中的 ${ids.length} 个会话吗？此操作不可恢复。'),
      onOk: () {},
    );
    if (confirmed != true) {
      selectMode.value = false;
      return;
    }

    await SessionStore.instance.deleteSessions(ids);
    selectMode.value = false;
  }

  Future<void> _createSession(BuildContext context) async {
    try {
      await SessionStore.instance.createAndOpen();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText('创建失败: $e')));
      }
    }
  }
}
