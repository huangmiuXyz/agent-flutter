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
import 'package:agent/features/settings/models/provider_info.dart';
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

  /// 把 default_model 写入「当前生效位置」并刷新列表。
  ///
  /// 与 [resolveModel] 的读取规则保持一致：
  /// - 当前是全局智能体 → 写全局 config.json（ConfigStore）；
  /// - 当前是非全局智能体 → 写入该智能体自己的 config.json。
  ///
  /// 返回是否成功（智能体配置写入失败时返回 false）。
  Future<bool> setDefaultModel(String provider, String model) async {
    final agent = currentAgent.value;
    if (agent == null || agent.isGlobal) {
      ConfigStore.instance.mutate((m) {
        m['default_model'] = {'provider': provider, 'model': model};
      });
      return true;
    }
    try {
      final cfg = await AgentConfigHelper.readConfig(agent.configPath) ?? {};
      cfg['default_model'] = {'provider': provider, 'model': model};
      await bridge_api.writeAgentConfig(
        configPath: agent.configPath,
        configJson: AgentConfigHelper.encode(cfg),
      );
      // 刷新列表使 resolveModel 的新结果通过信号传导到 UI
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 把工作目录写入「当前生效位置」并刷新列表。
  ///
  /// 与 [resolveWorkDir] 的读取规则保持一致：
  /// - 当前是全局智能体 → 写全局 config.json（ConfigStore）；
  /// - 当前是非全局智能体 → 写入该智能体自己的 config.json。
  ///
  /// 无论写入哪里，都会记入全局历史记录（最近使用列表）。
  /// 返回是否成功（智能体配置写入失败时返回 false）。
  Future<bool> setWorkDir(String path) async {
    final agent = currentAgent.value;
    if (agent == null || agent.isGlobal) {
      ConfigStore.instance.updateWorkDir(path);
      return true;
    }
    try {
      final cfg = await AgentConfigHelper.readConfig(agent.configPath) ?? {};
      cfg['work_dir'] = path;
      await bridge_api.writeAgentConfig(
        configPath: agent.configPath,
        configJson: AgentConfigHelper.encode(cfg),
      );
      ConfigStore.instance.recordWorkDirHistory(path);
      // 刷新列表使 resolveWorkDir 的新结果通过信号传导到 UI
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
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

  /// 解析当前生效的推理强度等级（provider-default / none / minimal / low /
  /// medium / high / max）。
  ///
  /// 读取规则与 [resolveModel] 一致：非全局智能体优先读自己的 config.json，
  /// 否则读全局配置；按「真正生效」的 (provider, model) 定位 `available_models`
  /// 中该模型的条目，其 `reasoning_effort` 优先，回退到 provider 级字段。
  /// 字段缺失或为空 = provider-default（省略参数）；旧配置遗留的 "xhigh"
  /// 归一为标准化等级 "max"。
  String resolveReasoningEffort() {
    final resolved = resolveModel();
    final agent = currentAgent.value;
    final data =
        (agent == null || agent.isGlobal)
            ? ConfigStore.instance.data.value
            : (AgentConfigHelper.readConfigSync(agent.configPath) ?? {});
    final cfg = findProviderConfig(data, resolved.provider);
    if (cfg == null) return kReasoningEffortProviderDefault;
    // 模型条目上的字段优先
    final loc = _locateModelEntry(data, resolved.provider, resolved.model);
    if (loc != null) {
      final item = loc.list[loc.index];
      if (item is Map) {
        final v = item['reasoning_effort'] as String?;
        if (v != null && v.isNotEmpty) {
          return v == 'xhigh' ? kReasoningEffortXhigh : v;
        }
      }
    }
    // 回退到 provider 级字段
    final raw = cfg['reasoning_effort'] as String?;
    if (raw == null || raw.isEmpty) return kReasoningEffortProviderDefault;
    if (raw == 'xhigh') return kReasoningEffortXhigh;
    return raw;
  }

  /// 把推理强度写入「当前生效位置」（`available_models` 中该模型条目的
  /// `reasoning_effort` 字段）。
  ///
  /// 与 [resolveReasoningEffort] 的读写规则保持一致：
  /// - 当前是全局智能体 → 写全局 config.json（ConfigStore）；
  /// - 当前是非全局智能体 → 写入该智能体自己的 config.json；
  /// - [effort] 为 null 时删除该字段（= 回退到 provider 级字段）；
  /// - [effort] 为 provider-default 时写入 `provider-default`（= 显式省略参数，
  ///   使用该模型提供商的默认推理行为，覆盖 provider 级配置）。
  ///
  /// 返回是否成功（找不到当前模型的条目或写入失败时返回 false）。
  Future<bool> setReasoningEffort(String? effort) async {
    final resolved = resolveModel();
    if (resolved.provider.isEmpty || resolved.model.isEmpty) return false;
    final agent = currentAgent.value;
    if (agent == null || agent.isGlobal) {
      if (_locateModelEntry(
            ConfigStore.instance.data.value,
            resolved.provider,
            resolved.model,
          ) ==
          null) {
        return false;
      }
      ConfigStore.instance.mutate((m) {
        _applyModelReasoningEffort(m, resolved.provider, resolved.model, effort);
      });
      return true;
    }
    try {
      final cfg = await AgentConfigHelper.readConfig(agent.configPath) ?? {};
      if (_locateModelEntry(cfg, resolved.provider, resolved.model) == null) {
        return false;
      }
      _applyModelReasoningEffort(cfg, resolved.provider, resolved.model, effort);
      await bridge_api.writeAgentConfig(
        configPath: agent.configPath,
        configJson: AgentConfigHelper.encode(cfg),
      );
      // 刷新列表使 resolveReasoningEffort 的新结果通过信号传导到 UI
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 在 provider 配置的 `available_models` 中定位模型条目，返回 (列表, 下标)；
  /// provider 配置或模型条目不存在时返回 null。
  static ({List<dynamic> list, int index})? _locateModelEntry(
    Map<String, dynamic> data,
    String provider,
    String model,
  ) {
    final cfg = findProviderConfig(data, provider);
    if (cfg == null) return null;
    final rawList = cfg['available_models'];
    if (rawList is! List) return null;
    for (int i = 0; i < rawList.length; i++) {
      final item = rawList[i];
      final name = item is String
          ? item
          : (item is Map ? item['name'] as String? : null);
      if (name == model) return (list: rawList, index: i);
    }
    return null;
  }

  /// 在模型条目上写入 `reasoning_effort`（字符串条目自动升级为
  /// `{"name": ..., "reasoning_effort": ...}` 对象）。调用前须先经
  /// [_locateModelEntry] 确认条目存在。
  ///
  /// [effort] 为 null 时删除模型条目上的字段（回退到 provider 级字段）；
  /// 为 [kReasoningEffortProviderDefault] 时显式写入 `provider-default`，
  /// 覆盖 provider 级配置（否则删除字段会回退到 provider 级的 `none` 等值，
  /// 导致 UI 上选择 Default 后仍显示 provider 级的值）。
  static void _applyModelReasoningEffort(
    Map<String, dynamic> data,
    String provider,
    String model,
    String? effort,
  ) {
    final loc = _locateModelEntry(data, provider, model)!;
    final item = loc.list[loc.index];
    if (effort == null) {
      if (item is Map) item.remove('reasoning_effort');
      // 字符串条目本来就没有该字段，无需改动
    } else if (item is Map) {
      item['reasoning_effort'] = effort;
    } else {
      loc.list[loc.index] = {'name': item, 'reasoning_effort': effort};
    }
  }
}
