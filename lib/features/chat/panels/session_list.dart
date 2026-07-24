import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/services/llm/llm_providers.dart';
import 'package:agent/services/session/session_manager.dart';
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
class SessionList extends HookConsumerWidget {
  const SessionList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 加载会话列表
    useEffect(() {
      SessionManager.instance.loadSessions(
        service: ref.read(llmServiceProvider),
        dbPath: ref.read(dbPathProvider),
      );
      return null;
    }, []);

    return SignalBuilder(
      builder: (context) {
        final mgr = SessionManager.instance;
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

        final sorted = List<api.SessionInfo>.from(sessions)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        return SingleChildScrollView(
          child: AppList(
            size: AppListSize.small,
            containerPadding: EdgeInsets.zero,
            itemGap: 0,
            children: sorted.map((session) {
              final isSelected = session.id == selectedId;
              return AppListItem(
                key: ValueKey(session.id),
                label: session.name,
                labelWidget: InlineField(
                  controller: TextEditingController(text: session.name),
                  size: FieldSize.sm,
                  onSubmitted: (newName) async {
                    if (newName.trim().isEmpty ||
                        newName.trim() == session.name)
                      return;
                    final service = ref.read(llmServiceProvider);
                    final dbPath = ref.read(dbPathProvider);
                    await service.renameSession(
                      dbPath: dbPath,
                      sessionId: session.id,
                      name: newName.trim(),
                    );
                    SessionManager.instance.renameSession(
                      session.id,
                      newName.trim(),
                    );
                  },
                ),
                trailing: _formatSessionTime(session.updatedAt),
                active: isSelected,
                intrinsicHeight: true,
                itemRadius: BorderRadius.zero,
                onTap: () async {
                  await SessionManager.instance.switchTo(
                    session.id,
                    service: ref.read(llmServiceProvider),
                    dbPath: ref.read(dbPathProvider),
                  );
                  SessionManager.instance.selectedId.value = session.id;
                },
                hoverActions: [
                  AppIconButton(
                    icon: 'trash2',
                    size: ButtonSize.sm,
                    hoverStyle: false,
                    tooltip: '删除会话',
                    onPressed: () async {
                      final confirmed = await AppDialog.show(
                        context: context,
                        title: '删除会话',
                        child: AppText('确定要删除「${session.name}」吗？此操作不可恢复。'),
                        onOk: () {},
                      );
                      if (confirmed == true) {
                        final service = ref.read(llmServiceProvider);
                        final dbPath = ref.read(dbPathProvider);
                        await service.deleteSession(
                          dbPath: dbPath,
                          sessionId: session.id,
                        );
                        if (selectedId == session.id) {
                          SessionManager.instance.selectedId.value = null;
                        }
                        SessionManager.instance.removeSession(session.id);
                      }
                    },
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
