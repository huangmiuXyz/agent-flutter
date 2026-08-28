/// 聊天中的检查点卡片 — 与工具调用 / 深度思考等展开 part 共用同一个
/// [ChatExpandablePart] 组件。
///
/// 编辑级检查点（apply_patch 成功后创建）显示在对应 tool_call part 之前
/// （检查点代表"编辑前状态"，恢复入口先于修改出现），
/// 消息级检查点（turn 收尾）挂在用户消息下方。收起时只显示标题行；
/// 展开后展示方向 tab（恢复 / 重新应用）、文件信息与差异 diff，
/// 底部常驻"恢复 / 重新应用"按钮（与检查点面板行为一致）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/features/chat/custom_tools_render/diff_code_block.dart';
import 'package:agent/features/chat/widgets/chat_expandable_part.dart';
import 'package:agent/features/checkpoints/checkpoint_actions.dart';
import 'package:agent/features/checkpoints/checkpoint_list.dart';
import 'package:agent/rust_bridge/api/checkpoints.dart' as api;
import 'package:agent/rust_bridge/api/types.dart' as api_types;
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/tab/app_tab_bar.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 聊天检查点卡片：单个检查点的展示 + 恢复/重新应用入口。
class ChatCheckpointPart extends HookWidget {
  const ChatCheckpointPart({super.key, required this.cp});

  final api_types.CheckpointInfo cp;

  /// 编辑级（partId 非空）还是消息级（整轮消息）。
  bool get _isMessageLevel => cp.partId == null;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    // 恢复 / 重新应用成功后 +1，强制展开区重新拉取 diff
    final refreshTick = useState(0);

    return ChatExpandablePart(
      // 摘要作为收起时的次要内容（展开区详情见 argumentsBuilder）
      content: cp.summary.isEmpty
          ? (_isMessageLevel ? '整轮消息' : '编辑文件')
          : cp.summary,
      iconName: 'fileCode',
      title: _isMessageLevel ? '整轮消息检查点' : '文件检查点',
      titleColor: custom.colors.accent,
      // 展开内容自定义构建：方向 tab + 文件信息 + diff（懒加载）
      argumentsBuilder: (context, _) =>
          _CheckpointDiffArea(cp: cp, refreshTick: refreshTick.value),
      // 底部常驻操作按钮（与检查点面板的恢复/重新应用一致）
      footer: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSecondaryButton(
            text: '恢复',
            icon: 'undo',
            size: ButtonSize.sm,
            onPressed: () => _run(
              context,
              restore: true,
              onApplied: () => refreshTick.value++,
            ),
          ),
          SizedBox(width: custom.spacing.xs),
          AppSecondaryButton(
            text: '重新应用',
            icon: 'redo',
            size: ButtonSize.sm,
            onPressed: () => _run(
              context,
              restore: false,
              onApplied: () => refreshTick.value++,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _run(
    BuildContext context, {
    required bool restore,
    required VoidCallback onApplied,
  }) async {
    if (restore) {
      await confirmRestoreCheckpoint(context, cp, onApplied: onApplied);
    } else {
      await confirmApplyCheckpoint(context, cp, onApplied: onApplied);
    }
  }
}

/// 展开区：方向 tab（恢复 / 重新应用）+ 操作徽标 / 文件数 / 时间 + diff。
///
/// diff 懒加载：展开挂载后拉取；方向切换 / [refreshTick] 变化（恢复或
/// 重新应用成功后）重新拉取。
class _CheckpointDiffArea extends HookWidget {
  const _CheckpointDiffArea({required this.cp, required this.refreshTick});

  final api_types.CheckpointInfo cp;

  /// 恢复 / 重新应用成功后的刷新计数（变化即重新拉取当前方向的 diff）。
  final int refreshTick;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    // false = 恢复（当前 → 编辑前）；true = 重新应用（当前 → 检查点）
    final applyMode = useState(false);
    final diffText = useState<String?>(null);
    final diffLoading = useState(false);
    final diffError = useState(false);
    // 手动刷新计数（tab 右侧刷新按钮 +1，清缓存重新拉取）
    final reloadTick = useState(0);
    // 已拉取的方向与刷新计数（避免同参数重复拉取）
    final diffDirection = useRef(false);
    final fetchedTick = useRef(-1);

    useEffect(() {
      final direction = applyMode.value;
      final alreadyFetched =
          diffText.value != null &&
          diffDirection.value == direction &&
          fetchedTick.value == refreshTick;
      if (alreadyFetched) return null;
      diffText.value = null;
      diffError.value = false;
      diffLoading.value = true;
      diffDirection.value = direction;
      fetchedTick.value = refreshTick;
      unawaited(() async {
        try {
          final text = direction
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
    }, [applyMode.value, refreshTick, reloadTick.value]);

    // 操作徽标（Rust 侧比较检查点与其父提交推断；无信息 → unknown 不显示）
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 文件信息行：操作徽标 + 文件数 / 摘要 + 时间
        Row(
          children: [
            if (operation.data case final op? when op != 'unknown') ...[
              operationBadge(custom, operationFromApi(op)),
              SizedBox(width: custom.spacing.xs),
            ],
            AppText(
              cp.summary.isEmpty
                  ? (cp.partId == null ? '整轮消息' : '编辑文件')
                  : cp.summary,
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const Spacer(),
            AppText(
              formatCheckpointTime(cp.createdAt.toInt()),
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
            ),
          ],
        ),
        SizedBox(height: custom.spacing.sm),
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
              onPressed: () {
                diffText.value = null;
                diffError.value = false;
                reloadTick.value++;
              },
            ),
          ],
        ),
        SizedBox(height: custom.spacing.sm),
        _buildDiff(
          custom,
          applyMode: applyMode.value,
          loading: diffLoading.value,
          error: diffError.value,
          text: diffText.value,
        ),
      ],
    );
  }

  Widget _buildDiff(
    CustomTheme custom, {
    required bool applyMode,
    required bool loading,
    required bool error,
    required String? text,
  }) {
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
    // 与聊天其他展开 part 一致：diff 用 chatPartExpandedMaxHeight 封顶
    return DiffCodeBlock(diff: text);
  }
}
