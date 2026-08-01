/// 聊天页智能体选择器。
///
/// 显示在消息输入框工具栏内，切换 [AgentStore.currentAgentId]。
/// 选中的智能体决定聊天时使用的配置文件（模型、MCP、技能）。
///
/// 与 [ModelSelector] 使用相同的 [PanelSelector] 组件，保持 UI 一致性。
///
/// 通过 [AgentStore.agents] 信号实时响应创建/删除操作。
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/agents/models/agent_info.dart';
import 'package:agent/features/agents/store/agent_store.dart';
import 'package:agent/features/settings/settings_page.dart';
import 'package:agent/layout/main_layout.dart' show showSettingsDialog;

import 'package:agent/widgets/select/panel_selector.dart';

/// 智能体选择器（使用 [PanelSelector] 统一风格）。
class AgentSelector extends HookWidget {
  const AgentSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AgentStore.instance;
    final agents = useExistingSignal(store.agents).value;
    final currentId = useExistingSignal(store.currentAgentId).value;

    // 首次挂载时加载一次
    useEffect(() {
      store.refresh();
      return null;
    }, const []);

    // 每次打开下拉面板时重新扫描，确保设置弹窗中创建/删除后即时生效；
    // 仅打开时刷新（PanelSelector.onBeforeOpen），收起时不触发
    final refresh = useCallback(() {
      store.refresh();
    }, []);

    // 当前选中项可能因删除而失效 → load() 已回退到全局，这里兜底
    final effectiveId = agents.any((a) => a.id == currentId)
        ? currentId
        : kGlobalAgentId;

    if (agents.isEmpty) {
      return const SizedBox.shrink();
    }

    // 打开菜单前刷新 agents 列表，刷新完成后信号更新 →
    // PanelSelector 的 useEffect([options]) 会原地刷新菜单内容
    return PanelSelector<String>(
      value: effectiveId,
      placeholder: '选择智能体',
      onBeforeOpen: refresh,
      options: [
        for (final agent in agents)
          PanelSelectorOption<String>(
            value: agent.id,
            label: agent.name,
            icon: agent.id == effectiveId ? 'check' : null,
            // 悬停齿轮：直达该智能体的设置编辑页（不改变当前选中）
            hoverIcon: 'settings',
            onHoverTap: () {
              showSettingsDialog(
                context,
                tab: SettingsTab.agents,
                agent: agent,
              );
            },
          ),
      ],
        onChanged: (id) {
          if (id != null) {
            store.select(id);
            // 选中后再刷新一次，保持列表最新
            refresh();
          }
        },
    );
  }
}
