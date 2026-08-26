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
import 'package:agent/features/settings/pages/local_model_page.dart';
import 'package:agent/features/settings/pages/mcp_detail_page.dart';
import 'package:agent/features/settings/pages/mcp_server_config_page.dart';
import 'package:agent/features/settings/pages/mcp_server_list_page.dart';
import 'package:agent/features/settings/pages/provider_config_page.dart';
import 'package:agent/features/settings/pages/provider_list_page.dart';
import 'package:agent/features/settings/pages/tool_permission_page.dart';
import 'package:agent/features/skills/models/skill_info.dart';
import 'package:agent/features/skills/pages/skill_detail_page.dart';
import 'package:agent/features/skills/pages/skill_list_page.dart';
import 'package:agent/features/skills/store/skill_store.dart';
import 'package:agent/rust_bridge/api/skills.dart' as bridge;
import 'package:agent/store/config_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/utils/platform.dart';
import 'package:agent/widgets/divider/app_divider.dart';
import 'package:agent/widgets/list/app_list.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Settings category tabs.
enum SettingsTab { display, models, mcp, localModels, skills, tools, agents }

/// 设置面板的跳转目标（tab / 提供商 / 智能体）。
///
/// 设置面板是单例弹窗：已打开时再次触发打开入口，不会叠加新面板，
/// 而是通过更新 [settingsPanelTarget] 把已打开的面板导航到目标页。
class SettingsTarget {
  const SettingsTarget({this.tab, this.provider, this.agent});

  final SettingsTab? tab;
  final ProviderInfo? provider;
  final AgentInfo? agent;
}

/// 当前设置面板的跳转目标；null 表示无待处理目标。
final ValueNotifier<SettingsTarget?> settingsPanelTarget = ValueNotifier(null);

const _sidebarsItems = [
  _TabItem(SettingsTab.display, '显示', 'palette'),
  _TabItem(SettingsTab.models, '模型提供商', 'cpu'),
  _TabItem(SettingsTab.localModels, '本地模型', 'hardDrive'),
  _TabItem(SettingsTab.mcp, 'MCP 服务器', 'server'),
  _TabItem(SettingsTab.skills, '技能', 'puzzle'),
  _TabItem(SettingsTab.tools, '工具权限', 'lock'),
  _TabItem(SettingsTab.agents, '智能体', 'robot'),
];

class _TabItem {
  final SettingsTab tab;
  final String name;
  final String icon;
  const _TabItem(this.tab, this.name, this.icon);
}

class SettingsPage extends HookWidget {
  const SettingsPage({
    super.key,
    this.initialTab,
    this.initialProvider,
    this.initialAgent,
  });

  /// 打开时直接定位到的 tab（默认模型提供商）。
  final SettingsTab? initialTab;

  /// 打开时直接定位到的提供商配置页。
  final ProviderInfo? initialProvider;

  /// 打开时直接定位到的智能体编辑页。
  final AgentInfo? initialAgent;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final activeTab = useState(initialTab ?? SettingsTab.models);
    final selectedProvider = useState<ProviderInfo?>(initialProvider);
    final showAddProvider = useState(false);
    final selectedMcp = useState<McpServerInfo?>(null);
    final showAddMcp = useState(false);
    final selectedMcpDetail = useState<McpServerInfo?>(null);
    final selectedSkill = useState<SkillInfo?>(null);
    final skills = useState<List<SkillInfo>>([]);
    final selectedAgent = useState<AgentInfo?>(initialAgent);
    final showAgentEditor = useState(initialAgent != null);
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

    // ── 单例面板：已打开时收到新的跳转请求，就地导航而不是叠加新面板 ──
    final target = useValueListenable(settingsPanelTarget);
    useEffect(() {
      final t = target;
      if (t == null) return null;
      if (t.tab != null && t.tab != activeTab.value) {
        activeTab.value = t.tab!;
        resetSubStates();
      }
      if (t.provider != null) {
        selectedProvider.value = t.provider;
      }
      if (t.agent != null) {
        selectedAgent.value = t.agent;
        showAgentEditor.value = true;
      }
      return null;
    }, [target]);

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
      case SettingsTab.localModels:
        content = const LocalModelPage();
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
      case SettingsTab.tools:
        // 工具权限（全局 config.json）；与智能体编辑页的入口共用同一编辑页
        content = ToolPermissionPage(
          configPath: ConfigStore.instance.configPath,
        );
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

    // ── 移动端：顶部横向滚动 Tab + 单栏内容 ──
    if (isMobilePlatform) {
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: custom.spacing.sm,
                  vertical: custom.spacing.xs,
                ),
                child: Row(
                  children: [
                    for (final item in _sidebarsItems)
                      _MobileSettingsTab(
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
              const AppDivider(extent: 1, thickness: 1),
              Expanded(
                child: Material(color: Colors.transparent, child: content),
              ),
            ],
          ),
        ),
      );
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
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      custom.spacing.xs,
                      custom.spacing.md,
                      custom.spacing.xs,
                      0,
                    ),
                    child: AppList(
                      size: AppListSize.small,
                      children: [
                        for (final item in _sidebarsItems)
                          AppListItem(
                            icon: item.icon,
                            label: item.name,
                            active: activeTab.value == item.tab,
                            // 激活/悬停背景圆角与下拉选择面板（radii.sm）保持一致
                            itemRadius: custom.radii.sm,
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

/// 移动端设置页顶部 Tab：胶囊按钮（窄屏横向滚动，6 个分类平铺放不下）。
class _MobileSettingsTab extends StatelessWidget {
  const _MobileSettingsTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(right: custom.spacing.xs),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: custom.controls.smallHeight,
          padding: EdgeInsets.symmetric(horizontal: custom.spacing.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? custom.colors.accent.withValues(alpha: 0.12)
                : custom.colors.hover,
            borderRadius: custom.radii.xs,
          ),
          child: AppText(
            label,
            variant: AppTextVariant.caption,
            color: active ? custom.colors.accent : custom.colors.textPrimary,
            style: active ? const TextStyle(fontWeight: FontWeight.w600) : null,
          ),
        ),
      ),
    );
  }
}
