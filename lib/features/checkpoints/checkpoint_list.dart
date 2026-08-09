/// 检查点视图右侧 — 检查点列表
///
/// 展示当前选中路径下所有会话的检查点（时间倒序），
/// 每项显示时间、会话名、摘要（涉及文件 / 整轮消息）、文件数，
/// hover 出"恢复"按钮。恢复是非破坏性的：只回退该次编辑涉及的文件
/// + 停止对话，不删除检查点记录、不动聊天（对齐设计文档 §1.5）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/chat/custom_tools_render/diff_code_block.dart';
import 'package:agent/rust_bridge/api/checkpoints.dart' as api;
import 'package:agent/rust_bridge/api/types.dart' as api_types;
import 'package:agent/services/sync/cross_window_sync.dart';
import 'package:agent/store/checkpoint_store.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/dialog/app_dialog.dart';
import 'package:agent/widgets/text/app_text.dart';

String _formatTime(int timestampSec) {
  final now = DateTime.now();
  final date = DateTime.fromMillisecondsSinceEpoch(timestampSec * 1000);
  final diff = now.difference(date);

  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
  if (diff.inDays < 1) return '${diff.inHours} 小时前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  return '${date.month}/${date.day}';
}

/// 右侧检查点列表（替换聊天内容区显示）。
class CheckpointList extends HookWidget {
  const CheckpointList({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final store = CheckpointStore.instance;
    final checkpoints = useExistingSignal(store.checkpoints);
    final loading = useExistingSignal(store.loading);
    final workDir = useExistingSignal(store.currentWorkDir);
    // 会话名映射（id → name），来自已有会话列表
    final sessionList = useExistingSignal(SessionStore.instance.sessionList);
    final sessionName = <String, String>{
      for (final s in sessionList.value) s.id: s.name,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 标题区 ──
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: custom.spacing.md,
            vertical: custom.spacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: custom.colors.separator)),
          ),
          child: Row(
            children: [
              Expanded(
                child: AppText(
                  workDir.value ?? '',
                  variant: AppTextVariant.body,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              AppIconButton(
                icon: 'refresh',
                size: ButtonSize.sm,
                tooltip: '刷新',
                onPressed: () => store.refreshAll(),
              ),
            ],
          ),
        ),
        Expanded(
          child: loading.value
              ? const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : checkpoints.value.isEmpty
              ? Center(
                  child: AppText(
                    '该路径下暂无检查点',
                    variant: AppTextVariant.caption,
                    color: custom.colors.textSecondary,
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(custom.spacing.sm),
                  itemCount: checkpoints.value.length,
                  itemBuilder: (context, i) => _CheckpointItem(
                    cp: checkpoints.value[i],
                    sessionName:
                        sessionName[checkpoints.value[i].sessionId] ?? '',
                  ),
                ),
        ),
      ],
    );
  }
}

class _CheckpointItem extends HookWidget {
  const _CheckpointItem({required this.cp, required this.sessionName});

  final api_types.CheckpointInfo cp;
  final String sessionName;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final isMessageLevel = cp.partId == null;
    final fileCount = cp.files.length;
    // 展开状态 + 恢复细节（懒加载，展开时才拉取）
    final expanded = useState(false);
    final diffText = useState<String?>(null);
    final diffLoading = useState(false);
    final diffError = useState(false);

    useEffect(() {
      if (!expanded.value) return null;
      if (diffText.value != null || diffLoading.value || diffError.value) {
        return null;
      }
      diffLoading.value = true;
      unawaited(() async {
        try {
          final text = await api.checkpointDiff(
            commitSha: cp.commitSha,
            workDir: cp.workDir,
            files: cp.files,
          );
          diffText.value = text;
        } catch (_) {
          diffError.value = true;
        } finally {
          diffLoading.value = false;
        }
      }());
      return null;
    }, [expanded.value]);

    return Padding(
      padding: EdgeInsets.only(bottom: custom.spacing.xs),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: custom.spacing.sm,
          vertical: custom.spacing.sm,
        ),
        decoration: BoxDecoration(
          color: custom.colors.hover,
          borderRadius: custom.radii.sm,
          border: Border.all(color: custom.colors.separator),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  isMessageLevel
                      ? Icons.chat_bubble_outline
                      : Icons.edit_outlined,
                  size: 16,
                  color: custom.colors.textSecondary,
                ),
                SizedBox(width: custom.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (sessionName.isNotEmpty) ...[
                            AppText(
                              sessionName,
                              variant: AppTextVariant.body,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: custom.spacing.xs),
                          ],
                          AppText(
                            _formatTime(cp.createdAt),
                            variant: AppTextVariant.caption,
                            color: custom.colors.textSecondary,
                          ),
                          SizedBox(width: custom.spacing.xs),
                          AppText(
                            isMessageLevel ? '整轮消息' : '$fileCount 个文件',
                            variant: AppTextVariant.caption,
                            color: custom.colors.textSecondary,
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      AppText(
                        cp.summary.isEmpty
                            ? (isMessageLevel ? '整轮消息' : '编辑文件')
                            : cp.summary,
                        variant: AppTextVariant.caption,
                        color: custom.colors.textSecondary,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                AppIconButton(
                  icon: expanded.value ? 'chevronDown' : 'chevronRight',
                  size: ButtonSize.sm,
                  tooltip: expanded.value ? '收起恢复细节' : '查看恢复细节',
                  onPressed: () => expanded.value = !expanded.value,
                ),
                AppIconButton(
                  icon: 'rotateCcw',
                  size: ButtonSize.sm,
                  tooltip: '恢复',
                  onPressed: () => _confirmRestore(context),
                ),
              ],
            ),
            if (expanded.value)
              Padding(
                padding: EdgeInsets.only(top: custom.spacing.sm),
                child: _buildDiffArea(
                  context,
                  loading: diffLoading.value,
                  error: diffError.value,
                  text: diffText.value,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 展开区域：恢复细节 diff（复用聊天 DiffCodeBlock 渲染）。
  Widget _buildDiffArea(
    BuildContext context, {
    required bool loading,
    required bool error,
    required String? text,
  }) {
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
    if (error) {
      return AppText(
        '获取恢复细节失败（请确认工作目录仍为 git 仓库）',
        variant: AppTextVariant.caption,
        color: custom.colors.textSecondary,
      );
    }
    if (text == null || text.isEmpty) {
      return AppText(
        '当前内容已与编辑前一致，无需恢复',
        variant: AppTextVariant.caption,
        color: custom.colors.textSecondary,
      );
    }
    // 展开区域填满屏幕：diff 内容上限取视口高度（减去固定 UI 空间），
    // 超过后虚拟滚动，聊天内嵌场景仍用默认 320 封顶。
    return DiffCodeBlock(
      diff: text,
      maxHeight: MediaQuery.sizeOf(context).height * 0.8,
    );
  }

  Future<void> _confirmRestore(BuildContext context) async {
    final confirmed = await AppDialog.show(
      context: context,
      title: '恢复文件',
      okText: '恢复',
      child: AppText(
        '将把本次${cp.partId == null ? '对话' : '编辑'}涉及的 ${cp.files.length} 个文件恢复到编辑前状态，并停止当前对话。\n'
        '此操作会覆盖这些文件的当前内容，且不影响检查点与聊天记录（可反复恢复）。',
      ),
      onOk: () {},
    );
    if (confirmed != true || !context.mounted) return;

    final summary = await CheckpointStore.instance.restore(cp);
    if (!context.mounted) return;
    if (summary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('恢复失败，请检查工作目录是否为 git 仓库')),
      );
      return;
    }

    final affected = [...summary.restored, ...summary.deleted];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AppText(
          '已恢复 ${summary.restored.length} 个文件'
          '${summary.deleted.isEmpty ? '' : '，删除 ${summary.deleted.length} 个新增文件'}',
        ),
      ),
    );

    // 停止当前对话（对齐 Zed #42537）
    final sid = SessionStore.instance.selectedId.value;
    if (sid != null) {
      SessionStore.instance.cancelStreaming(sid);
    }

    // 通知编辑器子窗口重新加载受影响文件
    if (affected.isNotEmpty) {
      unawaited(CrossWindowSync.notify('checkpointRestored', affected));
    }
  }
}
