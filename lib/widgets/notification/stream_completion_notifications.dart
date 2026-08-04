/// 流式对话结束通知弹窗 — 应用内右下角自动弹出
///
/// 挂在 [MainLayout] body 的 Stack 顶层，监听 [NotificationStore.notices]，
/// 在右下角堆叠展示流结束通知卡片：
/// - 点击卡片 → 切换到对应会话
/// - 点击 × 或超时（见 [NotificationStore.displayDuration]）→ 关闭
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:agent/store/notification_store.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 通知弹层 — 空列表时不占位，有通知时右下角滑入卡片。
class StreamCompletionNotifications extends StatelessWidget {
  const StreamCompletionNotifications({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return SignalBuilder(
      builder: (_) {
        final notices = NotificationStore.instance.notices.value;
        if (notices.isEmpty) return const SizedBox.shrink();

        return Align(
          alignment: Alignment.bottomRight,
          // 非 Positioned 子项：Align 只在其子项区域内响应命中，
          // 其余区域点击事件正常穿透到下层聊天界面
          child: Padding(
            padding: EdgeInsets.all(custom.spacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final notice in notices) ...[
                  _NoticeCard(
                    key: ValueKey(notice.id),
                    notice: notice,
                    onClose: () =>
                        NotificationStore.instance.dismiss(notice.id),
                    onTap: () => _openSession(notice),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 打开通知对应的会话（与左侧会话列表点击行为一致）。
  void _openSession(StreamCompletionNotice notice) {
    NotificationStore.instance.dismiss(notice.id);
    final store = SessionStore.instance;
    if (store.selectedId.value != notice.sessionId) {
      store.selectedId.value = notice.sessionId;
    }
    unawaited(store.switchTo(notice.sessionId));
  }
}

/// 单条通知卡片：右下角滑入 + 淡入入场动画。
class _NoticeCard extends StatelessWidget {
  final StreamCompletionNotice notice;
  final VoidCallback onClose;
  final VoidCallback onTap;

  const _NoticeCard({
    super.key,
    required this.notice,
    required this.onClose,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final statusColor = notice.isError
        ? custom.colors.danger
        : custom.colors.success;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: custom.radii.md,
          child: Container(
            width: 320,
            padding: EdgeInsets.fromLTRB(
              custom.spacing.md,
              custom.spacing.sm,
              custom.spacing.xs,
              custom.spacing.sm,
            ),
            decoration: BoxDecoration(
              color: custom.colors.cardBackground,
              borderRadius: custom.radii.md,
              border: Border.all(color: custom.colors.cardBorder),
              boxShadow: custom.shadows.medium,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: AppIcon(
                    notice.isError ? 'alertCircle' : 'check',
                    size: custom.typography.bodySize,
                    color: statusColor,
                  ),
                ),
                SizedBox(width: custom.spacing.sm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        notice.title,
                        variant: AppTextVariant.body,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 2),
                      AppText(
                        notice.message,
                        variant: AppTextVariant.caption,
                        color: custom.colors.textSecondary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                AppIconButton(
                  icon: 'x',
                  size: ButtonSize.sm,
                  hoverStyle: false,
                  tooltip: '关闭',
                  onPressed: onClose,
                ),
              ],
            ),
          ),
        ),
      ),
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset((1 - t) * 24, 0),
            child: child,
          ),
        );
      },
    );
  }
}
