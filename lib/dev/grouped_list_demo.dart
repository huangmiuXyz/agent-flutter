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
          AppText('AppList 列表示例', variant: AppTextVariant.title),
          SizedBox(height: custom.spacing.sm),
          AppText(
            '展示平面列表和分组列表两种形态',
            variant: AppTextVariant.caption,
            color: custom.colors.textSecondary,
          ),
          SizedBox(height: custom.spacing.xl),

          // ════════════════════════════════════════════════════════════════
          //  平面列表 (Flat List)
          // ════════════════════════════════════════════════════════════════
          AppText(
            '平面列表 — AppListItem 直接放入 AppList',
            variant: AppTextVariant.subtitle,
          ),
          SizedBox(height: custom.spacing.sm),
          AppCard(
            minWidth: 260,
            scrollable: false,
            child: AppList(
              containerPadding: EdgeInsets.zero,
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
                AppListItem(
                  icon: 'trash',
                  label: '回收站',
                  active: selectedIndex.value == 3,
                  onTap: () => selectedIndex.value = 3,
                ),
              ],
            ),
          ),

          SizedBox(height: custom.spacing.xl),

          // ════════════════════════════════════════════════════════════════
          //  分组列表 (Grouped List)
          // ════════════════════════════════════════════════════════════════
          AppText('分组列表 — AppListGroup 组织分组', variant: AppTextVariant.subtitle),
          SizedBox(height: custom.spacing.sm),
          AppText(
            '使用 AppListGroup 包裹子项，可设置标题、图标和分组间分隔线',
            variant: AppTextVariant.caption,
            color: custom.colors.textSecondary,
          ),
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
                      active: selectedIndex.value == 4,
                      onTap: () => selectedIndex.value = 4,
                    ),
                    AppListItem(
                      icon: 'terminal',
                      label: '终端',
                      active: selectedIndex.value == 5,
                      onTap: () => selectedIndex.value = 5,
                    ),
                    AppListItem(
                      icon: 'settings',
                      label: '设置',
                      active: selectedIndex.value == 6,
                      onTap: () => selectedIndex.value = 6,
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
                      active: selectedIndex.value == 7,
                      onTap: () => selectedIndex.value = 7,
                    ),
                    AppListItem(
                      icon: 'fileCode',
                      label: 'backend-service',
                      active: selectedIndex.value == 8,
                      onTap: () => selectedIndex.value = 8,
                    ),
                    AppListItem(
                      icon: 'fileCode',
                      label: 'mobile-app',
                      active: selectedIndex.value == 9,
                      onTap: () => selectedIndex.value = 9,
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
                      active: selectedIndex.value == 10,
                      onTap: () => selectedIndex.value = 10,
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: custom.spacing.xl),

          // ════════════════════════════════════════════════════════════════
          //  紧凑模式对比 (Size Comparison)
          // ════════════════════════════════════════════════════════════════
          AppText('尺寸对比：normal vs small', variant: AppTextVariant.subtitle),
          SizedBox(height: custom.spacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    AppText('normal', variant: AppTextVariant.caption),
                    SizedBox(height: custom.spacing.xs),
                    AppCard(
                      minWidth: 120,
                      scrollable: false,
                      child: AppList(
                        containerPadding: EdgeInsets.zero,
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
                          AppListItem(
                            icon: 'trash',
                            label: '回收站',
                            active: selectedIndex.value == 14,
                            onTap: () => selectedIndex.value = 14,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: custom.spacing.md),
              Expanded(
                child: Column(
                  children: [
                    AppText('small', variant: AppTextVariant.caption),
                    SizedBox(height: custom.spacing.xs),
                    AppCard(
                      minWidth: 120,
                      scrollable: false,
                      child: AppList(
                        size: AppListSize.small,
                        containerPadding: EdgeInsets.zero,
                        children: [
                          AppListItem(
                            icon: 'square',
                            label: '仪表盘',
                            active: selectedIndex.value == 15,
                            onTap: () => selectedIndex.value = 15,
                          ),
                          AppListItem(
                            icon: 'terminal',
                            label: '终端',
                            active: selectedIndex.value == 16,
                            onTap: () => selectedIndex.value = 16,
                          ),
                          AppListItem(
                            icon: 'settings',
                            label: '设置',
                            active: selectedIndex.value == 17,
                            onTap: () => selectedIndex.value = 17,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
