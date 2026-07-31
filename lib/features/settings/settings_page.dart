/// Settings page — left sidebar navigation + right content area.
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/features/agents/models/agent_info.dart';
import 'package:agent/features/agents/pages/agent_edit_page.dart';
import 'package:agent/features/agents/pages/agent_list_page.dart';
import 'package:agent/features/settings/models/mcp_server_info.dart';
import 'package:agent/features/settings/models/provider_info.dart';
import 'package:agent/features/settings/pages/add_mcp_server_page.dart';
import 'package:agent/features/settings/pages/add_provider_page.dart';
import 'package:agent/features/settings/pages/display_settings_page.dart';
import 'package:agent/features/settings/pages/font_settings_page.dart';
import 'package:agent/features/settings/pages/mcp_detail_page.dart';
import 'package:agent/features/settings/pages/mcp_server_config_page.dart';
import 'package:agent/features/settings/pages/mcp_server_list_page.dart';
import 'package:agent/features/settings/pages/provider_config_page.dart';
import 'package:agent/features/settings/pages/provider_list_page.dart';
import 'package:agent/features/skills/models/skill_info.dart';
import 'package:agent/features/skills/pages/skill_detail_page.dart';
import 'package:agent/features/skills/pages/skill_list_page.dart';
import 'package:agent/features/skills/store/skill_store.dart';
import 'package:agent/rust_bridge/api.dart' as bridge;
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/list/app_list.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Settings category tabs.
enum SettingsTab { display, models, mcp, skills, agents }

const _sidebarsItems = [
  _TabItem(SettingsTab.display, '显示', 'palette'),
  _TabItem(SettingsTab.models, '模型提供商', 'cpu'),
  _TabItem(SettingsTab.mcp, 'MCP 服务器', 'server'),
  _TabItem(SettingsTab.skills, '技能', 'puzzle'),
  _TabItem(SettingsTab.agents, '智能体', 'robot'),
];

class _TabItem {
  final SettingsTab tab;
  final String name;
  final String icon;
  const _TabItem(this.tab, this.name, this.icon);
}

class SettingsPage extends HookWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final activeTab = useState(SettingsTab.models);
    final selectedProvider = useState<ProviderInfo?>(null);
    final showAddProvider = useState(false);
    final selectedMcp = useState<McpServerInfo?>(null);
    final showAddMcp = useState(false);
    final selectedMcpDetail = useState<McpServerInfo?>(null);
    final selectedSkill = useState<SkillInfo?>(null);
    final skills = useState<List<SkillInfo>>([]);
    final selectedAgent = useState<AgentInfo?>(null);
    final showAgentEditor = useState(false);
    final showFontSettings = useState(false);

    // ── 切换到技能 tab 时自动扫描 ──
    useEffect(() {
      if (activeTab.value == SettingsTab.skills && skills.value.isEmpty) {
        bridge.scanGlobalSkills().then((discovered) {
          SkillStore.instance.load(discovered);
          skills.value = SkillStore.instance.skills.value.values.toList();
        });
      }
      return null;
    }, [activeTab.value]);

    // ── 切换 tab 时重置所有子状态 ──
    void resetSubStates() {
      selectedProvider.value = null;
      showAddProvider.value = false;
      selectedMcp.value = null;
      selectedMcpDetail.value = null;
      showAddMcp.value = false;
      selectedSkill.value = null;
      selectedAgent.value = null;
      showAgentEditor.value = false;
      showFontSettings.value = false;
    }

    // ── Right content ──
    Widget content;
    switch (activeTab.value) {
      case SettingsTab.display:
        if (showFontSettings.value) {
          content = FontSettingsPage(
            onBack: () => showFontSettings.value = false,
          );
        } else {
          content = DisplaySettingsPage(
            onFontSettingsTap: () => showFontSettings.value = true,
          );
        }
      case SettingsTab.models:
        if (showAddProvider.value) {
          content = AddProviderPage(
            onBack: () => showAddProvider.value = false,
            onSaved: (p) {
              showAddProvider.value = false;
              selectedProvider.value = p;
            },
          );
        } else if (selectedProvider.value != null) {
          content = ProviderConfigPage(
            provider: selectedProvider.value!,
            onBack: () => selectedProvider.value = null,
          );
        } else {
          content = ProviderListPage(
            onProviderTap: (p) => selectedProvider.value = p,
            onAddProvider: () => showAddProvider.value = true,
          );
        }
      case SettingsTab.mcp:
        if (selectedMcpDetail.value != null) {
          content = McpDetailPage(
            server: selectedMcpDetail.value!,
            onBack: () => selectedMcpDetail.value = null,
          );
        } else if (showAddMcp.value) {
          content = AddMcpServerPage(onBack: () => showAddMcp.value = false);
        } else if (selectedMcp.value != null) {
          content = McpServerConfigPage(
            server: selectedMcp.value!,
            onBack: () => selectedMcp.value = null,
            onManageDetail: () => selectedMcpDetail.value = selectedMcp.value,
          );
        } else {
          content = McpServerListPage(
            onServerTap: (s) => selectedMcp.value = s,
            onAddServer: () => showAddMcp.value = true,
          );
        }
      case SettingsTab.skills:
        if (selectedSkill.value != null) {
          content = SkillDetailPage(
            skill: selectedSkill.value!,
            onBack: () => selectedSkill.value = null,
          );
        } else {
          content = SkillListPage(
            skills: skills.value,
            onSkillTap: (s) => selectedSkill.value = s,
            onRescan: () async {
              final discovered = await bridge.scanGlobalSkills();
              SkillStore.instance.load(discovered);
              skills.value = SkillStore.instance.skills.value.values.toList();
            },
          );
        }
      case SettingsTab.agents:
        if (showAgentEditor.value) {
          content = AgentEditPage(
            agent: selectedAgent.value,
            onBack: () {
              showAgentEditor.value = false;
              selectedAgent.value = null;
            },
            onSaved: () {
              showAgentEditor.value = false;
              selectedAgent.value = null;
            },
          );
        } else {
          content = AgentListPage(
            onAgentTap: (a) {
              selectedAgent.value = a;
              showAgentEditor.value = true;
            },
            onCreateTap: () {
              selectedAgent.value = null;
              showAgentEditor.value = true;
            },
          );
        }
    }

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left sidebar ──
          SizedBox(
            width: 200,
            child: Container(
              color: custom.colors.panel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      custom.spacing.sm,
                      custom.spacing.md,
                      custom.spacing.sm,
                      custom.spacing.sm,
                    ),
                    child: AppText('设置', variant: AppTextVariant.subtitle),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: custom.spacing.xs,
                    ),
                    child: AppList(
                      size: AppListSize.small,
                      children: [
                        for (final item in _sidebarsItems)
                          AppListItem(
                            icon: item.icon,
                            label: item.name,
                            active: activeTab.value == item.tab,
                            onTap: () {
                              activeTab.value = item.tab;
                              resetSubStates();
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Sidebar divider ──
          Container(width: 1, color: custom.colors.separator),

          // ── Right content ──
          Expanded(
            child: Material(color: Colors.transparent, child: content),
          ),
        ],
      ),
    );
  }
}
