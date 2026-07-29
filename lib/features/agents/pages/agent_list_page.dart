/// 智能体列表页 — 展示全局智能体 + 所有自定义智能体。
///
/// 结构和 [SkillListPage] 一致：
/// - "全局智能体"置顶（始终显示，不可删除）
/// - 自定义智能体卡片式列表，点击进入编辑、可删除
/// - 顶部有 "创建智能体" 按钮
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/agents/models/agent_info.dart';
import 'package:agent/features/agents/store/agent_store.dart';
import 'package:agent/rust_bridge/api.dart' as bridge;
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/list/app_big_list.dart';

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

    final global = agents.where((a) => a.isGlobal).toList();
    final customs = agents.where((a) => !a.isGlobal).toList();

    Future<void> deleteAgent(AgentInfo agent) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('删除智能体'),
          content: Text('确定要删除智能体「${agent.name}」吗？该操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        await bridge.deleteAgent(agentDir: agent.directoryPath);
        // load() 内部会在被删的是当前选中项时自动回退到全局智能体
        await store.refresh();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
        }
      }
    }

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
    if (customs.isNotEmpty) {
      groups.add(
        AppBigGroup(
          label: '自定义',
          children: [
            for (final a in customs)
              AppBigRow(
                name: a.name,
                description: a.description.isEmpty ? a.id : a.description,
                icon: 'robot',
                clickable: true,
                onTap: () => onAgentTap(a),
                actions: [
                  AppIconButton(
                    icon: 'trash',
                    size: ButtonSize.sm,
                    tooltip: '删除',
                    onPressed: () => deleteAgent(a),
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
