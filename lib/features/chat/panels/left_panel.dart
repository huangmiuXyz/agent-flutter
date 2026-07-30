import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/chat/panels/session_list.dart';
import 'package:agent/store/config_store.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/services/llm/llm_service.dart';
import 'package:agent/services/session/session_state.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/dialog/app_dialog.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 左侧面板 — 会话列表（支持批量选择与删除）
class LeftPanel extends HookWidget {
  const LeftPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final selectMode = useSignal(false);
    final selectedIds = useSignal(<String>{});

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
            child: _buildHeader(context, custom, selectMode, selectedIds),
          ),
          // ── Session list ──
          Expanded(
            child: SessionList(
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
  ) {
    if (selectMode.value) {
      return Row(
        children: [
          Expanded(
            child: AppText(
              selectedIds.value.isEmpty
                  ? '选择会话'
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
                onPressed: () =>
                    _batchDelete(context, selectMode, selectedIds),
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
            '对话',
            variant: AppTextVariant.body,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        AppIconButton(
          icon: 'checkSquare2',
          size: ButtonSize.sm,
          tooltip: '批量选择',
          onPressed: () {
            selectMode.value = true;
          },
        ),
        AppIconButton(
          icon: 'plus',
          size: ButtonSize.sm,
          onPressed: () => _createSession(context),
        ),
      ],
    );
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

    final service = LlmService();
    final dbPath = ConfigStore.instance.dbPath;
    final mgr = SessionStore.instance;
    final currentDisplayedId = mgr.displayedSessionId.value;
    final currentSelectedId = mgr.selectedId.value;

    // 批量删除
    for (final sessionId in ids) {
      try {
        await service.deleteSession(dbPath: dbPath, sessionId: sessionId);
      } catch (_) {
        // 继续删除其余会话
      }
    }

    // 清理显示状态
    if (currentDisplayedId != null && ids.contains(currentDisplayedId)) {
      mgr.displayedSessionId.value = null;
    }
    if (currentSelectedId != null && ids.contains(currentSelectedId)) {
      mgr.selectedId.value = null;
    }

    // 从内存状态中移除
    final sessionsMap = Map<String, SessionState>.from(mgr.sessions.value);
    for (final id in ids) {
      sessionsMap.remove(id);
      mgr.removeSession(id);
    }
    mgr.sessions.value = sessionsMap;

    selectMode.value = false;
  }

  Future<void> _createSession(BuildContext context) async {
    try {
      final sessionId = await SessionStore.instance.createSession();
      SessionStore.instance.switchTo(sessionId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('创建失败: $e')));
      }
    }
  }
}
