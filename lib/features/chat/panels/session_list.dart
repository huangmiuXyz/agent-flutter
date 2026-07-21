import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/services/llm_providers.dart';
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
class SessionList extends ConsumerWidget {
  const SessionList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);
    final selectedId = ref.watch(selectedSessionProvider);
    final custom = CustomTheme.of(context);

    return sessionsAsync.when(
      loading: () => const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: AppText(
          '加载失败: ${err.toString()}',
          variant: AppTextVariant.caption,
          color: custom.colors.textSecondary,
        ),
      ),
      data: (sessions) {
        if (sessions.isEmpty) {
          return Center(
            child: AppText(
              '暂无会话',
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
            ),
          );
        }

        // Sort by updatedAt descending (newest first)
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
                        newName.trim() == session.name) {
                      return;
                    }
                    final service = ref.read(llmServiceProvider);
                    final dbPath = ref.read(dbPathProvider);
                    await service.renameSession(
                      dbPath: dbPath,
                      sessionId: session.id,
                      name: newName.trim(),
                    );
                    ref.invalidate(sessionsProvider);
                  },
                ),
                trailing: _formatSessionTime(session.updatedAt),
                active: isSelected,
                intrinsicHeight: true,
                itemRadius: BorderRadius.zero,
                onTap: () {
                  ref.read(selectedSessionProvider.notifier).select(session.id);
                },
                hoverActions: [
                  AppIconButton(
                    icon: 'trash2',
                    size: ButtonSize.sm,
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
                          ref
                              .read(selectedSessionProvider.notifier)
                              .select(null);
                        }
                        ref.invalidate(sessionsProvider);
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
