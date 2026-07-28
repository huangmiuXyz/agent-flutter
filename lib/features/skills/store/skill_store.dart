/// SkillStore — 技能状态管理（信号版）
///
/// 职责：
/// 1. 接收 Rust 扫描结果，以信号形式对外暴露
/// 2. 与 ConfigStore 的启禁状态合并，提供「仅启用的技能」计算信号
/// 3. 构建用于 system prompt 注入的技能目录文本
library;

import 'package:signals/signals.dart';

import 'package:agent/features/skills/models/skill_info.dart';
import 'package:agent/store/config_store.dart';
import 'package:agent/rust_bridge/api.dart' as bridge;

/// SkillStore 单例 — 所有技能相关的状态集中管理。
class SkillStore {
  static final instance = SkillStore._();
  SkillStore._();

  // ── 信号 ──

  /// 所有已发现的技能（id → SkillInfo）
  final skills = signal(<String, SkillInfo>{});

  /// 仅启用的技能列表（计算信号，自动追踪 ConfigStore 启禁状态变化）
  late final enabledSkills = computed(() {
    final states = ConfigStore.instance.loadSkillStates(
      ConfigStore.instance.data.value,
    );
    return skills.value.values
        .where((s) => states[s.id] ?? s.enabled)
        .toList();
  });

  // ── 方法 ──

  /// 加载 Rust 扫描结果，替换全部技能列表。
  void load(List<bridge.SkillMapInfo> discovered) {
    final map = <String, SkillInfo>{};
    for (final s in discovered) {
      map[s.id] = _fromRust(s);
    }
    skills.value = map;
  }

  /// 按 id 查找技能。
  SkillInfo? findById(String id) => skills.value[id];

  /// 构建 system prompt 用的技能目录文本。
  ///
  /// 如果无已启用的技能，返回空字符串。
  String buildSkillCatalog() {
    final list = enabledSkills.value;
    if (list.isEmpty) return '';

    final buf = StringBuffer();
    buf.writeln('## 可用技能');
    buf.writeln();
    for (final s in list) {
      buf.writeln('- ${s.id}: ${s.description}');
    }
    buf.writeln();
    buf.writeln(
      '当你需要某个技能的完整指导时，调用 `load_skill` 工具加载对应的 Markdown 内容。',
    );
    return buf.toString();
  }

  // ── 内部 ──

  /// 将 Rust 端扫描得到的 SkillMapInfo 转为已有的 SkillInfo 模型。
  SkillInfo _fromRust(bridge.SkillMapInfo r) {
    return SkillInfo(
      id: r.id,
      name: r.name,
      description: r.description,
      content: '',
      source: _sourceFromId(r.source),
      scope: r.scope,
      directoryPath: r.directoryPath,
      enabled: false,
    );
  }

  /// 将 Rust 的 source 字符串映射为 SkillSource 对象。
  SkillSource _sourceFromId(String id) {
    const all = [
      SkillSource.agents,
      SkillSource.claude,
      SkillSource.cursor,
      SkillSource.copilot,
      SkillSource.windsurf,
      SkillSource.cline,
      SkillSource.codex,
      SkillSource.zed,
      SkillSource.codebuddy,
      SkillSource.opencode,
      SkillSource.roo,
    ];
    for (final s in all) {
      if (s.id == id) return s;
    }
    return SkillSource(id, id);
  }
}
