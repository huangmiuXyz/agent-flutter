/// AgentStore — 智能体状态管理（信号版）
///
/// 职责：
/// 1. 接收 Rust 扫描结果，以信号形式对外暴露
/// 2. 维护当前选中的智能体 ID
/// 3. 提供当前智能体的配置文件路径（聊天时传给 Rust）
library;

import 'package:signals/signals.dart';

import 'package:agent/features/agents/models/agent_config_helper.dart';
import 'package:agent/features/agents/models/agent_info.dart';
import 'package:agent/rust_bridge/agent.dart' as bridge;
import 'package:agent/rust_bridge/api/agents.dart' as bridge_api;
import 'package:agent/store/config_store.dart';

/// AgentStore 单例 — 所有智能体相关的状态集中管理。
class AgentStore {
  static final instance = AgentStore._();
  AgentStore._();

  // ── 信号 ──

  /// 所有智能体列表（信号，保留顺序：全局智能体置顶）
  final agents = signal(<AgentInfo>[]);

  /// 当前选中的智能体 ID（初始化时从 config.json 恢复上次选中，未设置则回退全局）
  final currentAgentId = signal<String>(() {
    final saved = ConfigStore.instance.persistedAgentId.value;
    return saved.isNotEmpty ? saved : kGlobalAgentId;
  }());

  /// 当前选中的智能体（计算信号）
  late final currentAgent = computed(() {
    return agents.value
        .where((a) => a.id == currentAgentId.value)
        .firstOrNull;
  });

  /// 当前智能体的配置文件路径（聊天时传给 Rust）。
  ///
  /// 未选中或选中项不存在时回退到全局配置路径。
  late final currentConfigPath = computed(() {
    return currentAgent.value?.configPath ?? ConfigStore.instance.configPath;
  });

  // ── 方法 ──

  /// 从 Rust 重新扫描智能体列表并加载。
  ///
  /// 引擎不可用（Rust 未初始化/扫描失败）时静默保持现有列表，
  /// 避免引擎异常时聊天页直接崩溃。
  Future<void> refresh() async {
    try {
      final discovered = await bridge_api.listAgents(
        configPath: ConfigStore.instance.configPath,
      );
      load(discovered);
    } catch (_) {
      // 扫描失败不影响现有列表与聊天功能
    }
  }

  /// 加载 Rust 扫描结果，替换全部智能体列表。
  void load(List<bridge.AgentSummary> discovered) {
    agents.value = discovered
        .map(
          (s) => AgentInfo(
            id: s.id,
            name: s.name,
            description: s.description,
            configPath: s.configPath,
            directoryPath: s.directoryPath,
            isGlobal: s.isGlobal,
          ),
        )
        .toList();

    // 当前选中的智能体已被删除（或列表重扫后不存在）→ 回退到全局智能体
    if (agents.value.every((a) => a.id != currentAgentId.value)) {
      currentAgentId.value = kGlobalAgentId;
      // 同步清理持久化的选中记录，避免下次启动又指向已删除的智能体
      ConfigStore.instance.updateCurrentAgent(kGlobalAgentId);
    }
  }

  /// 切换到指定智能体（与切换模型一致，选中状态写回 config.json）。
  void select(String id) {
    currentAgentId.value = id;
    ConfigStore.instance.updateCurrentAgent(id);
  }

  /// 解析聊天应使用的 (provider, model)。
  ///
  /// 当前智能体的 config.json 中有 `default_model` 时优先使用；
  /// 否则回退到全局配置（ConfigStore）。
  ({String provider, String model}) resolveModel() {
    final fallback = (
      provider: ConfigStore.instance.currentProvider.value,
      model: ConfigStore.instance.currentModel.value,
    );
    final agent = currentAgent.value;
    if (agent == null || agent.isGlobal) return fallback;
    final cfg = AgentConfigHelper.readConfigSync(agent.configPath);
    return AgentConfigHelper.defaultModel(cfg ?? {}) ?? fallback;
  }

  /// 解析聊天应使用的工作目录。
  ///
  /// 当前智能体的 config.json 中有 `work_dir` 时优先使用；
  /// 否则回退到全局配置（ConfigStore）。
  String resolveWorkDir() {
    final fallback = ConfigStore.instance.workDir.value;
    final agent = currentAgent.value;
    if (agent == null || agent.isGlobal) return fallback;
    final cfg = AgentConfigHelper.readConfigSync(agent.configPath);
    final wd = AgentConfigHelper.workDir(cfg ?? {});
    return wd.isNotEmpty ? wd : fallback;
  }
}
