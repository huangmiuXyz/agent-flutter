import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/list/app_big_list.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Demo page for [AppBigList], [AppBigGroup], [AppBigRow], [AppBigEmpty].
class BigListDemo extends HookWidget {
  const BigListDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final searchQuery = useState('');

    // ── 模拟数据 ────────────────────────────────────────────
    final builtinAgents = [
      _Agent(id: 'default', name: '默认智能体', desc: '默认的智能体助手', builtin: true),
      _Agent(id: 'coder', name: '编程助手', desc: '帮助解决编程问题', builtin: true),
      _Agent(id: 'writer', name: '写作助手', desc: '协助文字创作', builtin: true),
    ];

    final customAgents = [
      _Agent(id: 'trans', name: '翻译助手', desc: '中英文翻译助手', builtin: false),
      _Agent(id: 'data', name: '数据分析师', desc: '数据分析和可视化', builtin: false),
    ];

    final query = searchQuery.value.trim().toLowerCase();

    bool matches(_Agent a) {
      if (query.isEmpty) return true;
      return a.name.toLowerCase().contains(query) ||
          a.desc.toLowerCase().contains(query);
    }

    final filteredBuiltin = builtinAgents.where(matches).toList();
    final filteredCustom = customAgents.where(matches).toList();
    final totalCount = filteredBuiltin.length + filteredCustom.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24),
      child: AppBigList(
        count: totalCount,
        countLabel: '个智能体',
        showSearch: true,
        searchTerm: searchQuery.value,
        onSearchChanged: (v) => searchQuery.value = v,
        searchPlaceholder: '搜索智能体',
        actions: [
          AppPrimaryButton(
            text: '创建智能体',
            icon: 'plus',
            size: ButtonSize.sm,
            onPressed: () {},
          ),
        ],
        emptyState: AppBigEmpty(
          icon: 'robot',
          title: searchQuery.value.isEmpty ? '尚未创建智能体' : '没有匹配的智能体',
          hint: searchQuery.value.isEmpty ? '点击"创建智能体"开始配置' : '试试其他关键词',
        ),
        children: [
          if (filteredBuiltin.isNotEmpty)
            AppBigGroup(
              label: '内置',
              children: [
                for (final agent in filteredBuiltin)
                  _AgentRow(agent: agent, builtin: true),
              ],
            ),
          if (filteredCustom.isNotEmpty)
            AppBigGroup(
              label: '自定义',
              children: [
                for (final agent in filteredCustom)
                  _AgentRow(agent: agent, builtin: false),
              ],
            ),
        ],
      ),
    );
  }
}

// ── 模拟数据模型 ──────────────────────────────────────────

class _Agent {
  final String id;
  final String name;
  final String desc;
  final bool builtin;
  const _Agent({
    required this.id,
    required this.name,
    required this.desc,
    required this.builtin,
  });
}

// ── 智能体行 ──────────────────────────────────────────────

class _AgentRow extends StatelessWidget {
  final _Agent agent;
  final bool builtin;

  const _AgentRow({required this.agent, required this.builtin});

  @override
  Widget build(BuildContext context) {
    return AppBigRow(
      name: agent.name,
      description: agent.desc,
      dot: agent.id == 'default',
      // Leading: custom widget (colored circle with initial)
      leading: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Center(
          child: AppText(
            agent.name[0],
            variant: AppTextVariant.body,
            color: Colors.white,
          ),
        ),
      ),
      // Hover actions
      actions: [
        AppIconButton(icon: 'pencil', size: ButtonSize.sm, onPressed: () {}),
        if (!builtin)
          AppIconButton(icon: 'trash', size: ButtonSize.sm, onPressed: () {}),
      ],
      onTap: () {},
    );
  }
}
