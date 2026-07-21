import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/services/llm_providers.dart';
import 'package:agent/theme/custom_theme.dart';
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
          ..sort((a, b) => (b.updatedAt as int).compareTo(a.updatedAt as int));

        return SingleChildScrollView(
          child: AppList(
            size: AppListSize.small,
            containerPadding: EdgeInsets.zero,
            itemGap: 0,
            children: sorted.map((session) {
              final isSelected = session.id == selectedId;
              return AppListItem(
                label: session.name,
                trailing: _formatSessionTime(session.updatedAt as int),
                active: isSelected,
                intrinsicHeight: true,
                itemRadius: BorderRadius.zero,
                onTap: () {
                  ref.read(selectedSessionProvider.notifier).select(session.id);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
