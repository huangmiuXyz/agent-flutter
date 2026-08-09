/// CheckpointStore — 检查点状态管理（信号版）
///
/// 职责：
/// 1. 维护左侧路径列表（listCheckpointPaths）
/// 2. 维护选中路径与其检查点列表（listCheckpoints）
/// 3. 提供恢复操作（restoreCheckpoint，只恢复该次编辑涉及的文件）
/// 4. 监听 `EngineEvent_CheckpointCreated` 实时刷新（路径计数 +1 / 插入列表顶部）
library;

import 'dart:async';

import 'package:signals/signals.dart';

import 'package:agent/rust_bridge/api/checkpoints.dart' as api;
import 'package:agent/rust_bridge/api/types.dart' as api_types;
import 'package:agent/store/config_store.dart';

class CheckpointStore {
  static final instance = CheckpointStore._();
  CheckpointStore._();

  /// 面板模式：false = 对话；true = 检查点
  final activeMode = signal(false);

  /// 左侧路径列表（work_dir 聚合）
  final paths = signal<List<api_types.CheckpointPathInfo>>([]);

  /// 当前选中的工作目录
  final currentWorkDir = signal<String?>(null);

  /// 当前选中路径下的检查点列表（时间倒序）
  final checkpoints = signal<List<api_types.CheckpointInfo>>([]);

  final loading = signal(false);

  bool get isCheckpointMode => activeMode.value;

  /// 切换对话/检查点模式；进入检查点模式时刷新数据。
  void toggleMode() {
    activeMode.value = !activeMode.value;
    if (activeMode.value) {
      unawaited(refreshAll());
    }
  }

  /// 进入检查点模式（已在检查点模式时不重复刷新）。
  void switchToCheckpoints() {
    if (!activeMode.value) {
      activeMode.value = true;
      unawaited(refreshAll());
    }
  }

  void switchToChat() => activeMode.value = false;

  /// 全量刷新：路径列表 + 当前路径的检查点列表。
  ///
  /// 默认选中第一个路径；若当前选中路径仍存在则保持。
  Future<void> refreshAll() async {
    await loadPaths();
    final dirs = paths.value;
    final current = currentWorkDir.value;
    if (current != null && dirs.any((p) => p.workDir == current)) {
      await loadCheckpoints(current);
    } else if (dirs.isNotEmpty) {
      currentWorkDir.value = dirs.first.workDir;
      await loadCheckpoints(dirs.first.workDir);
    } else {
      checkpoints.value = [];
    }
  }

  Future<void> loadPaths() async {
    try {
      paths.value = await api.listCheckpointPaths(
        dbPath: ConfigStore.instance.dbPath,
      );
    } catch (_) {
      // 数据库不可用等场景静默降级为空列表
      paths.value = [];
    }
  }

  Future<void> selectWorkDir(String workDir) async {
    if (currentWorkDir.value == workDir) return;
    currentWorkDir.value = workDir;
    await loadCheckpoints(workDir);
  }

  Future<void> loadCheckpoints(String workDir) async {
    loading.value = true;
    try {
      checkpoints.value = await api.listCheckpoints(
        dbPath: ConfigStore.instance.dbPath,
        workDir: workDir,
      );
    } catch (_) {
      checkpoints.value = [];
    } finally {
      loading.value = false;
    }
  }

  /// 恢复检查点（仅回退该次编辑涉及的文件，不删除记录/聊天）。
  ///
  /// 返回恢复摘要供 UI 展示；失败返回 null。
  Future<api_types.RestoreSummary?> restore(api_types.CheckpointInfo cp) async {
    try {
      return await api.restoreCheckpoint(
        commitSha: cp.commitSha,
        workDir: cp.workDir,
        files: cp.files,
      );
    } catch (_) {
      return null;
    }
  }

  /// 重新应用检查点（把该次编辑涉及的文件恢复到检查点状态，与恢复镜像）。
  ///
  /// 返回摘要供 UI 展示；失败返回 null。
  Future<api_types.RestoreSummary?> apply(api_types.CheckpointInfo cp) async {
    try {
      return await api.applyCheckpoint(
        commitSha: cp.commitSha,
        workDir: cp.workDir,
        files: cp.files,
      );
    } catch (_) {
      return null;
    }
  }

  /// 删除检查点路径（该 work_dir 下所有检查点记录；不影响 git 仓库）。
  ///
  /// 成功后刷新列表；失败返回 false。
  Future<bool> deletePaths(List<String> workDirs) async {
    try {
      await api.deleteCheckpointPaths(
        dbPath: ConfigStore.instance.dbPath,
        workDirs: workDirs,
      );
      await refreshAll();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 新检查点事件：更新路径计数；属于当前路径时插入列表顶部。
  void onCheckpointCreated(api_types.CheckpointInfo cp) {
    final exists = paths.value.any((p) => p.workDir == cp.workDir);
    if (exists) {
      paths.value = [
        for (final p in paths.value)
          if (p.workDir == cp.workDir)
            api_types.CheckpointPathInfo(
              workDir: p.workDir,
              checkpointCount: p.checkpointCount + 1,
              lastTime: cp.createdAt,
            )
          else
            p,
      ];
    } else {
      paths.value = [
        api_types.CheckpointPathInfo(
          workDir: cp.workDir,
          checkpointCount: 1,
          lastTime: cp.createdAt,
        ),
        ...paths.value,
      ];
    }
    if (currentWorkDir.value == cp.workDir) {
      checkpoints.value = [cp, ...checkpoints.value];
    }
  }
}
