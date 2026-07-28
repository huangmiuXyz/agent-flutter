import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:agent/store/config_store.dart';
import 'package:agent/store/message_queue_store.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 消息队列面板 — 显示待发送/注入的消息
///
/// 插入在消息列表和输入框之间。
class MessageQueuePanel extends HookWidget {
  const MessageQueuePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final store = MessageQueueStore.instance;

    return SignalBuilder(
      builder: (_) {
        final items = store.queue.value;
        final isExpanded = store.expanded.value;

        if (items.isEmpty) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: custom.colors.separator),
              bottom: BorderSide(color: custom.colors.separator),
            ),
            color: custom.colors.panel,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QueueHeader(
                count: items.length,
                isExpanded: isExpanded,
                onToggle: store.toggleExpanded,
                onClear: store.clear,
              ),
              if (isExpanded)
                ...items.map(
                  (msg) => _QueueItem(
                    message: msg,
                    onDelete: () => store.remove(msg.id),
                    onEdit: (newText) => store.edit(msg.id, newText),
                    onToggleSteer: () => store.toggleSteer(msg.id),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── 头部 ───

class _QueueHeader extends StatelessWidget {
  final int count;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onClear;

  const _QueueHeader({
    required this.count,
    required this.isExpanded,
    required this.onToggle,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: custom.spacing.sm,
          vertical: custom.spacing.xs,
        ),
        child: Row(
          children: [
            AnimatedRotation(
              turns: isExpanded ? 0.25 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: AppIcon(
                'chevronRight',
                size: custom.typography.captionSize,
                color: custom.colors.textSecondary,
              ),
            ),
            SizedBox(width: custom.spacing.sm),
            AppText(
              _pluralize(count),
              variant: AppTextVariant.caption,
              color: custom.colors.textPrimary,
            ),
            const Spacer(),
            InkWell(
              onTap: onClear,
              child: Padding(
                padding: EdgeInsets.all(custom.spacing.xs),
                child: AppText(
                  'Clear All',
                  variant: AppTextVariant.caption,
                  color: custom.colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _pluralize(int n) {
    if (n == 1) return '1 Queued Message';
    return '$n Queued Messages';
  }
}

// ─── 列表项 ───

class _QueueItem extends HookWidget {
  final QueuedMessage message;
  final VoidCallback onDelete;
  final ValueChanged<String> onEdit;
  final VoidCallback onToggleSteer;

  const _QueueItem({
    required this.message,
    required this.onDelete,
    required this.onEdit,
    required this.onToggleSteer,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final isEditing = useState(false);
    final editController = useTextEditingController(text: message.text);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: custom.spacing.sm,
        vertical: custom.spacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: custom.colors.separator.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: isEditing.value
          ? _buildEditing(custom, editController, isEditing)
          : _buildDisplay(custom, isEditing),
    );
  }

  Widget _buildDisplay(CustomTheme custom, ValueNotifier<bool> isEditing) {
    return Row(
      children: [
        // 状态圆点（steer 显示不同颜色）
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: message.steer
                ? const Color(0xFFFFA500) // 橙色 = steer
                : const Color(0xFF4DA6FF), // 蓝色 = 普通
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: custom.spacing.sm),
        // 消息文本
        Expanded(
          child: AppText(
            message.text,
            variant: AppTextVariant.body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: custom.spacing.sm),
        // 操作组
        _ActionGroup(
          message: message,
          onEdit: () => isEditing.value = true,
          onDelete: onDelete,
          onToggleSteer: onToggleSteer,
        ),
      ],
    );
  }

  Widget _buildEditing(
    CustomTheme custom,
    TextEditingController controller,
    ValueNotifier<bool> isEditing,
  ) {
    void submit() {
      final text = controller.text.trim();
      if (text.isNotEmpty) onEdit(text);
      isEditing.value = false;
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: custom.controls.smallHeight,
            child: TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(
                fontSize: custom.typography.bodySize,
                fontFamily: custom.typography.fontFamily,
                color: custom.colors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: custom.spacing.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: custom.radii.xs,
                  borderSide: BorderSide(color: custom.colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: custom.radii.xs,
                  borderSide: BorderSide(color: custom.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: custom.radii.xs,
                  borderSide: BorderSide(color: custom.colors.accent),
                ),
              ),
              onSubmitted: (_) => submit(),
            ),
          ),
        ),
        SizedBox(width: custom.spacing.xs),
        _SmallTextButton(label: 'Done', onPressed: submit),
        _SmallTextButton(
          label: 'Cancel',
          onPressed: () => isEditing.value = false,
        ),
      ],
    );
  }
}

// ─── 操作组 ───

class _ActionGroup extends StatelessWidget {
  final QueuedMessage message;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleSteer;

  const _ActionGroup({
    required this.message,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleSteer,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final iconColor = custom.colors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 删除
        _ActionIcon(
          icon: 'trash2',
          color: iconColor,
          tooltip: 'Delete',
          onPressed: onDelete,
        ),
        SizedBox(width: custom.spacing.xs),
        // 编辑
        _ActionIcon(
          icon: 'pencil',
          color: iconColor,
          tooltip: 'Edit',
          onPressed: onEdit,
        ),
        SizedBox(width: custom.spacing.sm),
        // Steer 切换按钮
        _SteerBadge(active: message.steer, onTap: onToggleSteer),
        SizedBox(width: custom.spacing.sm),
        // Send Now 按钮
        _SendNowButton(message: message),
      ],
    );
  }
}

// ─── Steer 标记切换按钮 ───

class _SteerBadge extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _SteerBadge({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: custom.radii.xs,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFFFA500).withValues(alpha: 0.15)
              : custom.colors.hover.withValues(alpha: 0.5),
          borderRadius: custom.radii.xs,
          border: active
              ? Border.all(
                  color: const Color(0xFFFFA500).withValues(alpha: 0.4),
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(
              'Steer',
              variant: AppTextVariant.caption,
              color: active
                  ? const Color(0xFFFFA500)
                  : custom.colors.textSecondary,
            ),
            if (active) ...[
              SizedBox(width: 3),
              AppIcon('check', size: 10, color: const Color(0xFFFFA500)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── 图标按钮 ───

class _ActionIcon extends StatelessWidget {
  final String icon;
  final Color color;
  final String? tooltip;
  final VoidCallback? onPressed;

  const _ActionIcon({
    required this.icon,
    required this.color,
    this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    Widget child = InkWell(
      onTap: onPressed,
      borderRadius: custom.radii.xs,
      child: Padding(
        padding: EdgeInsets.all(custom.spacing.xs),
        child: AppIcon(icon, size: custom.typography.bodySize, color: color),
      ),
    );

    if (tooltip != null) {
      child = Tooltip(message: tooltip!, child: child);
    }

    return child;
  }
}

// ─── Send Now 按钮 ───

class _SendNowButton extends StatelessWidget {
  final QueuedMessage message;

  const _SendNowButton({required this.message});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return InkWell(
      onTap: () async {
        final store = MessageQueueStore.instance;
        final sessionStore = SessionStore.instance;
        final sid = sessionStore.selectedId.value;
        if (sid == null) return;

        // 1. 从队列移除
        store.remove(message.id);

        // 2. 如果有活跃流，取消
        if (sessionStore.streamingSessionIds.value.contains(sid)) {
          await sessionStore.cancelStreaming(sid);
        }

        // 3. 确保会话存在
        final sessionId =
            sessionStore.selectedId.value ?? await sessionStore.createSession();

        // 4. 立即发送
        final provider = ConfigStore.instance.currentProvider.value;
        final model = ConfigStore.instance.currentModel.value;
        if (provider.isEmpty || model.isEmpty) return;

        sessionStore.sendMessage(
          sessionId: sessionId,
          provider: provider,
          model: model,
          prompt: message.text,
        );
      },
      borderRadius: custom.radii.xs,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: custom.spacing.sm,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: custom.colors.hover,
          borderRadius: custom.radii.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(
              'Send Now',
              variant: AppTextVariant.caption,
              color: custom.colors.textPrimary,
            ),
            SizedBox(width: 2),
            AppText(
              'Enter',
              variant: AppTextVariant.caption,
              color: custom.colors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 小型文字按钮 ───

class _SmallTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SmallTextButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return InkWell(
      onTap: onPressed,
      borderRadius: custom.radii.xs,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: custom.spacing.sm,
          vertical: custom.spacing.xs,
        ),
        child: AppText(
          label,
          variant: AppTextVariant.caption,
          color: custom.colors.accent,
        ),
      ),
    );
  }
}
