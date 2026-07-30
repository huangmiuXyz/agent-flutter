/// 智能体列表页 — 展示全局智能体 + 所有自定义智能体。
///
/// 结构和 [SkillListPage] 一致：
/// - "全局智能体"置顶（始终显示，不可删除）
/// - 自定义智能体按已启用/已禁用分组，每行可开关、点击编辑
/// - 顶部有 "创建智能体" 按钮
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/agents/models/agent_info.dart';
import 'package:agent/features/agents/store/agent_store.dart';
import 'package:agent/rust_bridge/api.dart' as bridge;
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/list/app_big_list.dart';
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

    // 加载所有自定义智能体的启用状态
    useEffect(() {
      final customs = agents.where((a) => !a.isGlobal).toList();
      if (customs.isEmpty) {
        enabledMap.value = {};
        return null;
      }
      Future<void> load() async {
        final map = <String, bool>{};
        for (final a in customs) {
          try {
            final raw = await bridge.readAgentConfig(configPath: a.configPath);
            final cfg = jsonDecode(raw) as Map<String, dynamic>;
            map[a.configPath] = cfg['enable'] as bool? ?? false;
          } catch (_) {
            map[a.configPath] = false;
          }
        }
        enabledMap.value = map;
      }
      load();
      return null;
    }, [agents.length]);

    bool isEnabled(AgentInfo a) {
      if (a.isGlobal) return true;
      return enabledMap.value[a.configPath] ?? false;
    }

    Future<void> toggleEnabled(AgentInfo agent, bool value) async {
      try {
        final raw = await bridge.readAgentConfig(configPath: agent.configPath);
        final cfg = jsonDecode(raw) as Map<String, dynamic>;
        cfg['enable'] = value;
        final json = '${const JsonEncoder.withIndent('  ').convert(cfg)}\n';
        await bridge.writeAgentConfig(
          configPath: agent.configPath,
          configJson: json,
        );
        await store.refresh();
        enabledMap.value = {...enabledMap.value, agent.configPath: value};
      } catch (_) {}
    }

    final global = agents.where((a) => a.isGlobal).toList();
    final customs = agents.where((a) => !a.isGlobal).toList();
    final enabledList = customs.where((a) => isEnabled(a)).toList();
    final disabledList = customs.where((a) => !isEnabled(a)).toList();

    final groups = <Widget>[];
    if (global.isNotEmpty) {
      groups.add(
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
                clickable: false,
              ),
          ],
        ),
      );
    }
    if (enabledList.isNotEmpty) {
      groups.add(
        AppBigGroup(
          label: '已启用',
          children: [
            for (final a in enabledList)
              AppBigRow(
                name: a.name,
                description: a.description.isEmpty ? a.id : a.description,
                icon: 'robot',
                dot: true,
                clickable: true,
                onTap: () => onAgentTap(a),
                actions: [
                  AppSwitch(
                    value: true,
                    onChanged: (v) => toggleEnabled(a, v),
                    size: SwitchSize.sm,
                  ),
                ],
              ),
          ],
        ),
      );
    }
    if (disabledList.isNotEmpty) {
      groups.add(
        AppBigGroup(
          label: '已禁用',
          children: [
            for (final a in disabledList)
              AppBigRow(
                name: a.name,
                description: a.description.isEmpty ? a.id : a.description,
                icon: 'robot',
                dot: false,
                clickable: true,
                onTap: () => onAgentTap(a),
                actions: [
                  AppSwitch(
                    value: false,
                    onChanged: (v) => toggleEnabled(a, v),
                    size: SwitchSize.sm,
                  ),
                ],
              ),
          ],
        ),
      );
    }

    return ContentFrame(
      child: AppBigList(
        key: ValueKey('agent_list_${agents.length}'),
        count: customs.length,
        countLabel: '个智能体',
        showSearch: false,
        actions: [
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
        children: groups,
      ),
    );
  }
}
