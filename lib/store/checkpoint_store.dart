/// CheckpointStore — 检查点状态管理（信号版）
///
/// 职责：
/// 1. 维护左侧路径列表（listCheckpointPaths）
/// 2. 维护选中路径与其检查点列表（listCheckpoints）
/// 3. 提供恢复操作（restoreCheckpoint，只恢复该次编辑涉及的文件）
/// 4. 监听 `EngineEvent_CheckpointCreated` 实时刷新（路径计数 +1 / 插入列表顶部）
///
/// 左右解耦（VS Code 式）：[leftMode] 只控制左侧面板显示会话列表还是
/// 检查点路径列表；右侧主视图（聊天内容 / 检查点列表）由 [showCheckpointView]
/// 控制，仅在点击对应列表项时切换。
library;

import 'dart:async';

import 'package:signals/signals.dart';

import 'package:agent/rust_bridge/api/checkpoints.dart' as api;
import 'package:agent/rust_bridge/api/types.dart' as api_types;
import 'package:agent/store/config_store.dart';

class CheckpointStore {
  static final instance = CheckpointStore._();
  CheckpointStore._();

  /// 左侧面板模式：false = 会话列表；true = 检查点路径列表。
  /// 仅影响左侧面板显示（VS Code 式：左侧 tab 不切换右侧视图）。
  final leftMode = signal(false);

  /// 右侧主视图：false = 聊天内容；true = 检查点列表。
  /// 左侧 tab 切换不改变它；点击会话切回聊天、点击检查点路径切到检查点。
  final showCheckpointView = signal(false);

  /// 左侧路径列表（work_dir 聚合）
  final paths = signal<List<api_types.CheckpointPathInfo>>([]);

  /// 当前选中的工作目录
  final currentWorkDir = signal<String?>(null);

  /// 当前选中路径下的检查点列表（时间倒序）
  final checkpoints = signal<List<api_types.CheckpointInfo>>([]);

  /// 按会话的检查点列表（聊天内嵌展示用；switchTo 时加载，事件实时插入）
  final sessionCheckpoints =
      signal<Map<String, List<api_types.CheckpointInfo>>>({});

  final loading = signal(false);

  bool get isLeftCheckpointMode => leftMode.value;

  /// 切换左侧面板模式；进入检查点模式时刷新数据。
  void toggleMode() {
    leftMode.value = !leftMode.value;
    if (leftMode.value) {
      unawaited(refreshAll());
    }
  }

  /// 左侧 tab 切到检查点（仅影响左侧列表；已在检查点模式时不重复刷新）。
  void switchToCheckpoints() {
    if (!leftMode.value) {
      leftMode.value = true;
      unawaited(refreshAll());
    }
  }

  /// 左侧 tab 切回会话列表（仅影响左侧列表）。
  void switchToChat() => leftMode.value = false;

  /// 点击会话：右侧主视图切回聊天内容。
  void showChatView() => showCheckpointView.value = false;

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

  /// 点击检查点路径：右侧切到检查点视图并加载其检查点列表。
  ///
  /// 即使选中的路径未变化也必须先把右侧切到检查点视图
  /// （点击已选中项同样属于「点击列表项」）。
  Future<void> selectWorkDir(String workDir) async {
    showCheckpointView.value = true;
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

  /// 加载指定会话的检查点（聊天内嵌展示用；时间倒序）。
  Future<void> loadSessionCheckpoints(String sessionId) async {
    try {
      final cps = await api.listCheckpoints(
        dbPath: ConfigStore.instance.dbPath,
        sessionId: sessionId,
      );
      sessionCheckpoints.value = {...sessionCheckpoints.value, sessionId: cps};
    } catch (_) {
      // 数据库不可用等场景静默降级为空列表
      sessionCheckpoints.value = {
        ...sessionCheckpoints.value,
        sessionId: const [],
      };
    }
  }

  /// 会话删除后清理其检查点缓存（聊天不再展示）。
  void removeSession(String sessionId) {
    if (!sessionCheckpoints.value.containsKey(sessionId)) return;
    sessionCheckpoints.value = {
      for (final e in sessionCheckpoints.value.entries)
        if (e.key != sessionId) e.key: e.value,
    };
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
    // 聊天内嵌展示：会话检查点列表顶部插入（会话未加载过则跳过，
    // 下次 switchTo 时按 DB 全量加载）
    final sessionCps = sessionCheckpoints.value[cp.sessionId];
    if (sessionCps != null) {
      sessionCheckpoints.value = {
        ...sessionCheckpoints.value,
        cp.sessionId: [cp, ...sessionCps],
      };
      // 事件快照不带 files（恢复范围/摘要需 git ref 元数据）：
      // git ref 已在事件发布前落盘，异步重载补齐全量数据
      unawaited(loadSessionCheckpoints(cp.sessionId));
    }
  }
}
