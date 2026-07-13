import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/list/app_list.dart';
import 'package:agent/widgets/text/app_text.dart';
import 'package:agent/widgets/card/app_card.dart';

class GroupedListDemo extends HookWidget {
  const GroupedListDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final selectedIndex = useState(0);

    return SingleChildScrollView(
      padding: EdgeInsets.all(custom.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText('AppListGroup 分组列表示例', variant: AppTextVariant.title),
          SizedBox(height: custom.spacing.sm),
          AppText(
            '在 AppList 中创建带标题的分组，适合侧边栏导航、设置面板等场景',
            variant: AppTextVariant.caption,
            color: custom.colors.textSecondary,
          ),
          SizedBox(height: custom.spacing.lg),

          // ── 示例1: 带图标的分组 ──
          AppText('带图标的分组标题', variant: AppTextVariant.subtitle),
          SizedBox(height: custom.spacing.sm),
          AppCard(
            minWidth: 260,
            scrollable: false,
            child: AppList(
              containerPadding: EdgeInsets.zero,
              children: [
                AppListGroup(
                  title: '导航',
                  icon: 'folderOpen',
                  children: [
                    AppListItem(
                      icon: 'square',
                      label: '仪表盘',
                      active: selectedIndex.value == 0,
                      onTap: () => selectedIndex.value = 0,
                    ),
                    AppListItem(
                      icon: 'terminal',
                      label: '终端',
                      active: selectedIndex.value == 1,
                      onTap: () => selectedIndex.value = 1,
                    ),
                    AppListItem(
                      icon: 'settings',
                      label: '设置',
                      active: selectedIndex.value == 2,
                      onTap: () => selectedIndex.value = 2,
                    ),
                  ],
                ),
                AppListGroup(
                  showDivider: true,
                  title: '开发项目',
                  icon: 'folderPlus',
                  children: [
                    AppListItem(
                      icon: 'fileCode',
                      label: 'agent-flutter',
                      active: selectedIndex.value == 3,
                      onTap: () => selectedIndex.value = 3,
                    ),
                    AppListItem(
                      icon: 'fileCode',
                      label: 'backend-service',
                      active: selectedIndex.value == 4,
                      onTap: () => selectedIndex.value = 4,
                    ),
                    AppListItem(
                      icon: 'fileCode',
                      label: 'mobile-app',
                      active: selectedIndex.value == 5,
                      onTap: () => selectedIndex.value = 5,
                    ),
                  ],
                ),
                AppListGroup(
                  showDivider: true,
                  title: '其他',
                  children: [
                    AppListItem(
                      icon: 'trash',
                      label: '回收站',
                      active: selectedIndex.value == 6,
                      onTap: () => selectedIndex.value = 6,
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: custom.spacing.xl),

          // ── 示例2: 不带图标的分组 ──
          AppText('不带图标的分组标题', variant: AppTextVariant.subtitle),
          SizedBox(height: custom.spacing.sm),
          AppCard(
            minWidth: 260,
            scrollable: false,
            child: AppList(
              containerPadding: EdgeInsets.zero,
              children: [
                AppListGroup(
                  title: '基本设置',
                  children: [
                    AppListItem(
                      label: '语言',
                      trailing: '中文',
                      active: selectedIndex.value == 7,
                      onTap: () => selectedIndex.value = 7,
                    ),
                    AppListItem(
                      label: '自动更新',
                      active: selectedIndex.value == 8,
                      onTap: () => selectedIndex.value = 8,
                    ),
                  ],
                ),
                AppListGroup(
                  showDivider: true,
                  title: '高级设置',
                  children: [
                    AppListItem(
                      label: '开发者模式',
                      active: selectedIndex.value == 9,
                      onTap: () => selectedIndex.value = 9,
                    ),
                    AppListItem(
                      label: '调试日志',
                      trailing: '关闭',
                      active: selectedIndex.value == 10,
                      onTap: () => selectedIndex.value = 10,
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: custom.spacing.xl),

          // ── 示例3: 紧凑分组（size: small） ──
          AppText('紧凑分组（size: small）', variant: AppTextVariant.subtitle),
          SizedBox(height: custom.spacing.sm),
          AppCard(
            minWidth: 240,
            scrollable: false,
            child: AppList(
              size: AppListSize.small,
              containerPadding: EdgeInsets.zero,
              children: [
                AppListGroup(
                  title: '导航',
                  icon: 'folderOpen',
                  children: [
                    AppListItem(
                      icon: 'square',
                      label: '仪表盘',
                      active: selectedIndex.value == 11,
                      onTap: () => selectedIndex.value = 11,
                    ),
                    AppListItem(
                      icon: 'terminal',
                      label: '终端',
                      active: selectedIndex.value == 12,
                      onTap: () => selectedIndex.value = 12,
                    ),
                    AppListItem(
                      icon: 'settings',
                      label: '设置',
                      active: selectedIndex.value == 13,
                      onTap: () => selectedIndex.value = 13,
                    ),
                  ],
                ),
                AppListGroup(
                  showDivider: true,
                  title: '开发项目',
                  icon: 'folderPlus',
                  children: [
                    AppListItem(
                      icon: 'fileCode',
                      label: 'agent-flutter',
                      active: selectedIndex.value == 14,
                      onTap: () => selectedIndex.value = 14,
                    ),
                    AppListItem(
                      icon: 'fileCode',
                      label: 'backend-service',
                      active: selectedIndex.value == 15,
                      onTap: () => selectedIndex.value = 15,
                    ),
                    AppListItem(
                      icon: 'fileCode',
                      label: 'mobile-app',
                      active: selectedIndex.value == 16,
                      onTap: () => selectedIndex.value = 16,
                    ),
                  ],
                ),
                AppListGroup(
                  showDivider: true,
                  title: '其他',
                  children: [
                    AppListItem(
                      icon: 'trash',
                      label: '回收站',
                      active: selectedIndex.value == 17,
                      onTap: () => selectedIndex.value = 17,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
