/// 智能体列表页 — 展示全局智能体 + 所有自定义智能体。
///
/// 结构和 [SkillListPage] 一致：
/// - "全局智能体"置顶（始终显示，不可删除）
/// - 自定义智能体按已启用/已禁用分组，每行可开关、点击编辑
/// - 顶部有 "重新扫描" 与 "创建智能体" 按钮
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/agents/models/agent_config_helper.dart';
import 'package:agent/features/agents/models/agent_info.dart';
import 'package:agent/features/agents/store/agent_store.dart';
import 'package:agent/rust_bridge/api/agents.dart' as bridge;
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/list/app_big_list.dart';
import 'package:agent/widgets/list/toggle_group_list.dart';
import 'package:agent/widgets/switch/app_switch.dart';

/// 智能体列表页。
class AgentListPage extends HookWidget {
  /// 点击某个自定义智能体（进入编辑）。
  final ValueChanged<AgentInfo> onAgentTap;

  /// 点击 "创建智能体"。
  final VoidCallback onCreateTap;

  const AgentListPage({
    super.key,
    required this.onAgentTap,
    required this.onCreateTap,
  });

  @override
  Widget build(BuildContext context) {
    final store = AgentStore.instance;
    final agents = useExistingSignal(store.agents).value;

    // ── 首次进入时扫描 ──
    useEffect(() {
      if (agents.isEmpty) {
        store.refresh();
      }
      return null;
    }, const []);

    // 缓存每个自定义智能体的启用状态（configPath → bool）
    final enabledMap = useState(<String, bool>{});

    // 刷新进行中（按钮禁用，避免重复点击）
    final refreshing = useState(false);

    // 加载所有自定义智能体的启用状态
    Future<void> loadEnabledStates() async {
      final customs = agents.where((a) => !a.isGlobal).toList();
      if (customs.isEmpty) {
        enabledMap.value = {};
        return;
      }
      final map = <String, bool>{};
      for (final a in customs) {
        final cfg = await AgentConfigHelper.readConfig(a.configPath);
        map[a.configPath] = cfg != null
            ? AgentConfigHelper.enabled(cfg)
            : false;
      }
      enabledMap.value = map;
    }

    // 列表变化时加载启用状态
    useEffect(() {
      loadEnabledStates();
      return null;
    }, [agents.length]);

    // 手动刷新：重新从 Rust 扫描智能体列表 + 重载启用状态
    Future<void> refreshList() async {
      refreshing.value = true;
      try {
        await store.refresh();
        await loadEnabledStates();
      } finally {
        refreshing.value = false;
      }
    }

    bool isEnabled(AgentInfo a) {
      if (a.isGlobal) return true;
      return enabledMap.value[a.configPath] ?? false;
    }

    Future<void> toggleEnabled(AgentInfo agent, bool value) async {
      try {
        final cfg = await AgentConfigHelper.readConfig(agent.configPath);
        if (cfg == null) return;
        cfg['enable'] = value;
        await bridge.writeAgentConfig(
          configPath: agent.configPath,
          configJson: AgentConfigHelper.encode(cfg),
        );
        await store.refresh();
        enabledMap.value = {...enabledMap.value, agent.configPath: value};
      } catch (_) {}
    }

    final global = agents.where((a) => a.isGlobal).toList();
    final customs = agents.where((a) => !a.isGlobal).toList();

    return ToggleGroupListPage<AgentInfo>(
      key: ValueKey('agent_list_${agents.length}'),
      items: customs,
      isEnabled: isEnabled,
      count: customs.length,
      countLabel: '个智能体',
      extraGroups: [
        if (global.isNotEmpty)
          AppBigGroup(
            label: '全局',
            children: [
              for (final a in global)
                AppBigRow(
                  name: a.name,
                  description: a.description.isEmpty
                      ? '默认智能体（根 config.json）'
                      : a.description,
                  icon: 'robot',
                  dot: true,
                  clickable: true,
                  onTap: () => onAgentTap(a),
                ),
            ],
          ),
      ],
      rowBuilder: (context, a) => AppBigRow(
        name: a.name,
        description: a.description.isEmpty ? a.id : a.description,
        icon: 'robot',
        dot: isEnabled(a),
        clickable: true,
        onTap: () => onAgentTap(a),
        actions: [
          AppSwitch(
            value: isEnabled(a),
            onChanged: (v) => toggleEnabled(a, v),
            size: SwitchSize.sm,
          ),
        ],
      ),
      actions: [
        AppPrimaryButton(
          text: '重新扫描',
          size: ButtonSize.sm,
          onPressed: refreshing.value ? null : refreshList,
        ),
        const SizedBox(width: 8),
        AppPrimaryButton(
          text: '创建智能体',
          icon: 'plus',
          size: ButtonSize.sm,
          onPressed: onCreateTap,
        ),
      ],
      emptyState: AppBigEmpty(
        icon: 'robot',
        title: '暂无自定义智能体',
        hint: '点击"创建智能体"，从全局配置出发组合模型、MCP 服务器和技能。',
      ),
    );
  }
}
