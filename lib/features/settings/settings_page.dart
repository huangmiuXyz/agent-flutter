/// Settings page — left sidebar navigation + right content area.
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/features/settings/models/provider_info.dart';
import 'package:agent/features/settings/pages/add_provider_page.dart';
import 'package:agent/features/settings/pages/provider_config_page.dart';
import 'package:agent/features/settings/pages/provider_list_page.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/list/app_list.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Settings category tabs.
enum SettingsTab { models }

const _sidebarsItems = [_TabItem(SettingsTab.models, '模型提供商', 'cpu')];

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

    // ── Right content ──
    Widget content;
    switch (activeTab.value) {
      case SettingsTab.models:
        if (showAddProvider.value) {
          content = AddProviderPage(
            onBack: () => showAddProvider.value = false,
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
                    child: AppText(
                      'Settings',
                      variant: AppTextVariant.subtitle,
                    ),
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
                              selectedProvider.value = null;
                              showAddProvider.value = false;
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
