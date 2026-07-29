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
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/select/panel_selector.dart';

/// 智能体选择器（使用 [PanelSelector] 统一风格）。
class AgentSelector extends HookWidget {
  const AgentSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final store = AgentStore.instance;
    final agents = useExistingSignal(store.agents).value;
    final currentId = useExistingSignal(store.currentAgentId).value;

    // 首次挂载时扫描（列表为空才触发）
    useEffect(() {
      store.refresh();
      return null;
    }, const []);

    // 当前选中项可能因删除而失效 → load() 已回退到全局，这里兜底
    final effectiveId = agents.any((a) => a.id == currentId)
        ? currentId
        : kGlobalAgentId;

    if (agents.isEmpty) {
      return const SizedBox.shrink();
    }

    // 用 agents.length + effectiveId 做 key，保证智能体列表变化时 PanelSelector 完全重建
    return PanelSelector<String>(
      key: ValueKey('agent_${agents.length}_$effectiveId'),
      value: effectiveId,
      placeholder: '选择智能体',
      options: [
        for (final agent in agents)
          PanelSelectorOption<String>(
            value: agent.id,
            label: agent.name,
            icon: agent.isGlobal ? 'check' : null,
          ),
      ],
      onChanged: (id) {
        if (id != null) store.select(id);
      },
    );
  }
}
