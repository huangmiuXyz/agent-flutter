/// 检查点恢复 / 重新应用的确认流程（检查点面板与聊天卡片共用）。
///
/// 恢复是非破坏性的：只回退该次编辑涉及的文件 + 停止对话，不删除
/// 检查点记录、不动聊天（对齐设计文档 §1.5）。重新应用为其镜像。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent/rust_bridge/api/types.dart' as api_types;
import 'package:agent/services/sync/cross_window_sync.dart';
import 'package:agent/store/checkpoint_store.dart';
import 'package:agent/store/notification_store.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/widgets/dialog/app_dialog.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 弹出确认框并执行恢复；成功后回调 [onApplied]（供调用方刷新 diff 预览）。
Future<void> confirmRestoreCheckpoint(
  BuildContext context,
  api_types.CheckpointInfo cp, {
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
    NotificationStore.instance.notify(
      message: '恢复失败，请检查工作目录是否为 git 仓库',
      isError: true,
    );
    return;
  }
  // 工作区已变化：刷新展开区的 diff 预览
  onApplied();

  final affected = [...summary.restored, ...summary.deleted];
  NotificationStore.instance.notify(
    title: '恢复完成',
    message:
        '已恢复 ${summary.restored.length} 个文件'
        '${summary.deleted.isEmpty ? '' : '，删除 ${summary.deleted.length} 个新增文件'}',
  );

  _afterApplied(cp, affected);
}

/// 弹出确认框并执行重新应用；成功后回调 [onApplied]。
Future<void> confirmApplyCheckpoint(
  BuildContext context,
  api_types.CheckpointInfo cp, {
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
    NotificationStore.instance.notify(
      message: '重新应用失败，请检查工作目录是否为 git 仓库',
      isError: true,
    );
    return;
  }
  // 工作区已变化：刷新展开区的 diff 预览
  onApplied();

  final affected = [...summary.restored, ...summary.deleted];
  NotificationStore.instance.notify(
    title: '重新应用完成',
    message:
        '已重新应用 ${summary.restored.length} 个文件'
        '${summary.deleted.isEmpty ? '' : '，删除 ${summary.deleted.length} 个文件'}',
  );

  _afterApplied(cp, affected);
}

/// 恢复 / 重新应用成功后的公共收尾：停止当前对话（对齐 Zed #42537）
/// + 通知编辑器子窗口重新加载受影响文件。
void _afterApplied(api_types.CheckpointInfo cp, List<String> affected) {
  final sid = SessionStore.instance.selectedId.value;
  if (sid != null) {
    SessionStore.instance.cancelStreaming(sid);
  }
  if (affected.isNotEmpty) {
    unawaited(CrossWindowSync.notify('checkpointRestored', affected));
  }
}
