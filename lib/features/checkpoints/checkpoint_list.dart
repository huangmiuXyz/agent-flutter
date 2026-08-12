/// 检查点视图右侧 — 检查点列表
///
/// 展示当前选中路径下所有会话的检查点（时间倒序），
/// 每项显示时间、会话名、摘要（涉及文件 / 整轮消息）、文件数，
/// hover 出"恢复"按钮。恢复是非破坏性的：只回退该次编辑涉及的文件
/// + 停止对话，不删除检查点记录、不动聊天（对齐设计文档 §1.5）。
library;

import 'dart:async';
import 'dart:math' as math;

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
import 'package:agent/widgets/tab/app_tab_bar.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 检查点操作类型（由 Rust 侧比较检查点与其父提交中文件的存在性推断）。
enum CheckpointOperation { added, modified, deleted, unknown }

/// API 字符串 → 操作类型（"unknown" 及其他未知值 → unknown）。
CheckpointOperation _operationFromApi(String? op) => switch (op) {
      'added' => CheckpointOperation.added,
      'modified' => CheckpointOperation.modified,
      'deleted' => CheckpointOperation.deleted,
      _ => CheckpointOperation.unknown,
    };

/// 操作类型徽标（新增=绿 / 修改=强调色 / 删除=红）。
Widget _operationBadge(CustomTheme custom, CheckpointOperation op) {
  final (label, color) = switch (op) {
    CheckpointOperation.added => ('新增', custom.colors.success),
    CheckpointOperation.modified => ('修改', custom.colors.accent),
    CheckpointOperation.deleted => ('删除', custom.colors.danger),
    CheckpointOperation.unknown => ('', custom.colors.textSecondary),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
    ),
    child: AppText(
      label,
      variant: AppTextVariant.caption,
      color: color,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
    ),
  );
}

/// 详细时间：`yyyy-MM-dd HH:mm:ss`（精确到秒）。
String _formatTime(int timestampSec) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestampSec * 1000);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
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
              : LayoutBuilder(
                  builder: (context, constraints) => ListView.builder(
                    padding: EdgeInsets.all(custom.spacing.sm),
                    itemCount: checkpoints.value.length,
                    itemBuilder: (context, i) => _CheckpointItem(
                      cp: checkpoints.value[i],
                      sessionName:
                          sessionName[checkpoints.value[i].sessionId] ?? '',
                      // 列表视口高度：展开项 diff 撑满可见区域
                      viewportHeight: constraints.maxHeight,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _CheckpointItem extends HookWidget {
  _CheckpointItem({
    required this.cp,
    required this.sessionName,
    required this.viewportHeight,
  });

  final api_types.CheckpointInfo cp;
  final String sessionName;

  /// 列表视口高度（由 [CheckpointList] 传入），展开时 diff 撑满可见区域。
  final double viewportHeight;

  /// 折叠头部测量锚点：展开 diff 时扣除头部高度，使整项恰好一屏。
  final GlobalKey _headerKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final isMessageLevel = cp.partId == null;
    final fileCount = cp.files.length;
    // 操作类型徽标（Rust 侧比较检查点与其父提交推断；无信息 → unknown 不显示）
    final operation = useFuture(
      useMemoized(
        () => api.checkpointOperation(
          commitSha: cp.commitSha,
          workDir: cp.workDir,
          files: cp.files,
        ),
        [cp.id, cp.commitSha],
      ),
    );
    // 展开状态 + 恢复/重新应用细节（懒加载，展开时才拉取，按方向缓存一份）
    final expanded = useState(false);
    final applyMode = useState(false); // false = 恢复；true = 重新应用
    final diffDirection = useState(false); // 当前 diffText 对应的方向
    final diffRefreshTick = useState(0); // 手动刷新计数（清缓存重新拉取）
    final diffText = useState<String?>(null);
    final diffLoading = useState(false);
    final diffError = useState(false);
    // 头部高度：build 期间不能读 context.size（会抛断言），改为帧后测量。
    // 折叠态首次布局即可测得，展开态头部尺寸不变；主题/缩放变化后，
    // 展开/收起切换时重新校准。
    final headerHeight = useState(0.0);

    useEffect(() {
      if (!expanded.value) {
        // 收起时丢弃缓存：下次展开自动重新拉取最新 diff
        diffText.value = null;
        diffError.value = false;
        return null;
      }
      // 方向切换：丢弃旧方向的缓存
      if (diffDirection.value != applyMode.value) {
        diffDirection.value = applyMode.value;
        diffText.value = null;
        diffError.value = false;
      }
      if (diffText.value != null || diffLoading.value || diffError.value) {
        return null;
      }
      diffLoading.value = true;
      unawaited(() async {
        try {
          final text = applyMode.value
              ? await api.checkpointApplyDiff(
                  commitSha: cp.commitSha,
                  workDir: cp.workDir,
                  files: cp.files,
                )
              : await api.checkpointDiff(
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
    }, [expanded.value, applyMode.value, diffRefreshTick.value]);

    // 帧后测量折叠头部高度（build 期间读 size 会抛错）
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final size = _headerKey.currentContext?.size;
        if (size != null && headerHeight.value != size.height) {
          headerHeight.value = size.height;
        }
      });
      return null;
    }, [expanded.value]);

    // 工作区变化后使 diff 缓存失效：清空并重新拉取当前方向
    void invalidateDiff() {
      diffText.value = null;
      diffError.value = false;
      diffRefreshTick.value++;
    }

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
              key: _headerKey,
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
                          if (operation.data case final op?
                              when op != 'unknown') ...[
                            _operationBadge(custom, _operationFromApi(op)),
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
                  icon: 'undo',
                  size: ButtonSize.sm,
                  tooltip: '恢复到编辑前',
                  onPressed: () =>
                      _confirmRestore(context, onApplied: invalidateDiff),
                ),
                AppIconButton(
                  icon: 'redo',
                  size: ButtonSize.sm,
                  tooltip: '重新应用检查点',
                  onPressed: () =>
                      _confirmApply(context, onApplied: invalidateDiff),
                ),
              ],
            ),
            if (expanded.value)
              Padding(
                padding: EdgeInsets.only(top: custom.spacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 方向 tab：恢复（当前 → 编辑前）/ 重新应用（当前 → 检查点）
                    Row(
                      children: [
                        Expanded(
                          child: AppTabBar(
                            tabs: const ['恢复', '重新应用'],
                            activeIndex: applyMode.value ? 1 : 0,
                            size: TabBarSize.sm,
                            onChanged: (i) => applyMode.value = i == 1,
                          ),
                        ),
                        SizedBox(width: custom.spacing.xs),
                        AppIconButton(
                          icon: 'refresh',
                          size: ButtonSize.sm,
                          tooltip: '刷新 diff',
                          onPressed: invalidateDiff,
                        ),
                      ],
                    ),
                    SizedBox(height: custom.spacing.sm),
                    _buildDiffArea(
                      context,
                      loading: diffLoading.value,
                      error: diffError.value,
                      text: diffText.value,
                      headerHeight: headerHeight.value,
                      applyMode: applyMode.value,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 展开区域：恢复/重新应用细节 diff（复用聊天 DiffCodeBlock 渲染）。
  Widget _buildDiffArea(
    BuildContext context, {
    required bool loading,
    required bool error,
    required String? text,
    required double headerHeight,
    required bool applyMode,
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
        applyMode
            ? '获取重新应用详情失败（请确认工作目录仍为 git 仓库）'
            : '获取恢复细节失败（请确认工作目录仍为 git 仓库）',
        variant: AppTextVariant.caption,
        color: custom.colors.textSecondary,
      );
    }
    if (text == null || text.isEmpty) {
      return AppText(
        applyMode ? '当前内容已与检查点一致，无需重新应用' : '当前内容已与编辑前一致，无需恢复',
        variant: AppTextVariant.caption,
        color: custom.colors.textSecondary,
      );
    }
    // 展开区域撑满列表视口：diff 上限 = 视口高度 - 折叠头部与四周留白，
    // 展开后整项恰好一屏（头部常驻、diff 内部滚动），而非固定 80% 窗口高；
    // 聊天内嵌场景仍用默认 chatPartExpandedMaxHeight 封顶。
    final maxDiffHeight =
        viewportHeight -
        headerHeight -
        custom.spacing.sm * 5 - // 列表上/下边距、容器上下内边距、展开区顶距
        custom.spacing.xs - // 列表项底部间距
        custom.controls.smallHeight - // 方向 tab 高度
        custom.spacing.sm; // tab 与 diff 间距
    return DiffCodeBlock(diff: text, maxHeight: math.max(maxDiffHeight, 120.0));
  }

  Future<void> _confirmRestore(
    BuildContext context, {
    required VoidCallback onApplied,
  }) async {
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
    // 工作区已变化：刷新展开区的 diff 预览
    onApplied();

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

  Future<void> _confirmApply(
    BuildContext context, {
    required VoidCallback onApplied,
  }) async {
    final confirmed = await AppDialog.show(
      context: context,
      title: '重新应用',
      okText: '重新应用',
      child: AppText(
        '将把本次${cp.partId == null ? '对话' : '编辑'}涉及的 ${cp.files.length} 个文件恢复到检查点（编辑后）状态，并停止当前对话。\n'
        '此操作会覆盖这些文件的当前内容，且不影响检查点与聊天记录（可反复应用）。',
      ),
      onOk: () {},
    );
    if (confirmed != true || !context.mounted) return;

    final summary = await CheckpointStore.instance.apply(cp);
    if (!context.mounted) return;
    if (summary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('重新应用失败，请检查工作目录是否为 git 仓库')),
      );
      return;
    }
    // 工作区已变化：刷新展开区的 diff 预览
    onApplied();

    final affected = [...summary.restored, ...summary.deleted];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AppText(
          '已重新应用 ${summary.restored.length} 个文件'
          '${summary.deleted.isEmpty ? '' : '，删除 ${summary.deleted.length} 个文件'}',
        ),
      ),
    );

    // 停止当前对话（与恢复一致，对齐 Zed #42537）
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
