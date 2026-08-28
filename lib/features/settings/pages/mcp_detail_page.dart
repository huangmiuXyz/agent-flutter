/// MCP 管理详情页 — 展示已连接 MCP 服务器的工具和资源列表，
/// 支持单独启用/禁用。
///
/// 数据通过 FRB 从 Rust 后端 `get_mcp_server_detail` 获取。
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/features/settings/models/mcp_server_info.dart';
import 'package:agent/rust_bridge/api/mcp.dart' as api;
import 'package:agent/rust_bridge/api/types.dart' as api;
import 'package:agent/store/config_store.dart';
import 'package:agent/store/notification_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/list/app_big_list.dart';
import 'package:agent/widgets/switch/app_switch.dart';
import 'package:agent/widgets/tab/app_tab_bar.dart';
import 'package:agent/widgets/text/app_text.dart';

/// MCP 管理详情页。
///
/// 结构参考 [ModelListPage]：不使用 Expanded，由 AppBigList 自行管理滚动。
class McpDetailPage extends HookWidget {
  final McpServerInfo server;
  final VoidCallback onBack;

  const McpDetailPage({super.key, required this.server, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final activeTab = useState(0); // 0=工具, 1=资源
    final loading = useState(true);
    final errorMsg = useState<String?>(null);
    final tools = useState<List<api.McpItemInfo>>([]);
    final resources = useState<List<api.McpItemInfo>>([]);
    final searchQuery = useState('');

    // ── 从 Rust 后端加载数据（仅在首次或切换服务器时加载）──
    useEffect(() {
      Future<void> load() async {
        loading.value = true;
        errorMsg.value = null;
        try {
          final detail = await api.getMcpServerDetail(serverName: server.name);
          tools.value = detail.tools;
          resources.value = detail.resources;
        } catch (e) {
          errorMsg.value = e.toString();
        }
        loading.value = false;
      }

      load();
      return null;
    }, [server.name]);

    // ── 切换开关 ──
    Future<void> handleToggle(String name, bool enabled) async {
      try {
        final isTools = activeTab.value == 0;
        ConfigStore.instance.updateMcpServers((list) {
          final idx = list.indexWhere((s) => s.name == server.name);
          if (idx == -1) return;

          final current = list[idx];
          final disabledList = List<String>.from(
            isTools ? current.disabledTools : current.disabledResources,
          );

          if (enabled) {
            disabledList.remove(name);
          } else if (!disabledList.contains(name)) {
            disabledList.add(name);
          }

          list[idx] = current.copyWith(
            disabledTools: isTools ? disabledList : null,
            disabledResources: !isTools ? disabledList : null,
          );
        });

        // 更新本地状态
        final upd = (isTools ? tools : resources).value.map((item) {
          if (item.name == name) {
            return api.McpItemInfo(
              name: item.name,
              description: item.description,
              enabled: enabled,
            );
          }
          return item;
        }).toList();
        if (isTools) {
          tools.value = upd;
        } else {
          resources.value = upd;
        }
      } catch (e) {
        NotificationStore.instance.notify(
          title: '操作失败',
          message: '$e',
          isError: true,
        );
      }
    }

    // ── 根据当前 Tab 决定显示列表 ──
    final currentItems = activeTab.value == 0 ? tools.value : resources.value;
    final query = searchQuery.value.trim().toLowerCase();
    bool matches(api.McpItemInfo item) {
      if (query.isEmpty) return true;
      return item.name.toLowerCase().contains(query);
    }

    final active = currentItems
        .where((item) => item.enabled && matches(item))
        .toList();
    final inactive = currentItems
        .where((item) => !item.enabled && matches(item))
        .toList();
    final total = active.length + inactive.length;

    final groups = <Widget>[];
    if (active.isNotEmpty) {
      groups.add(
        AppBigGroup(
          label: '已启用',
          children: [
            for (final item in active)
              _ItemRow(item: item, onToggle: handleToggle),
          ],
        ),
      );
    }
    if (inactive.isNotEmpty) {
      groups.add(
        AppBigGroup(
          label: '已禁用',
          children: [
            for (final item in inactive)
              _ItemRow(item: item, onToggle: handleToggle),
          ],
        ),
      );
    }

    return ContentFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 面包屑 ──
          AppBreadcrumb(
            items: [
              AppBreadcrumbItem('设置', onTap: () {}),
              AppBreadcrumbItem('MCP 服务器', onTap: () {}),
              AppBreadcrumbItem(server.name, onTap: onBack),
              AppBreadcrumbItem('管理详情'),
            ],
          ),
          SizedBox(height: custom.spacing.lg),

          // ── TabBar ──
          AppTabBar(
            tabs: const ['工具', '资源'],
            activeIndex: activeTab.value,
            onChanged: (i) => activeTab.value = i,
            size: TabBarSize.md,
          ),
          SizedBox(height: custom.spacing.md),

          // ── 列表（参考 ModelListPage 模式，不用 Expanded）──
          loading.value
              ? const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              : errorMsg.value != null
              ? Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                    child: AppText(
                      '加载失败: ${errorMsg.value}',
                      variant: AppTextVariant.caption,
                      color: custom.colors.danger,
                    ),
                  ),
                )
              : AppBigList(
                  count: total,
                  countLabel: activeTab.value == 0 ? '个工具' : '个资源',
                  showSearch: true,
                  searchTerm: searchQuery.value,
                  onSearchChanged: (v) => searchQuery.value = v,
                  searchPlaceholder: activeTab.value == 0
                      ? '搜索工具...'
                      : '搜索资源...',
                  emptyState: AppBigEmpty(
                    icon: activeTab.value == 0 ? 'terminal' : 'file',
                    title: query.isEmpty
                        ? (activeTab.value == 0 ? '暂无工具' : '暂无资源')
                        : '没有匹配的${activeTab.value == 0 ? "工具" : "资源"}',
                    hint: query.isEmpty ? '' : '试试其他关键词',
                  ),
                  children: groups,
                ),
        ],
      ),
    );
  }
}

/// 工具/资源列表行。
class _ItemRow extends StatelessWidget {
  final api.McpItemInfo item;
  final Future<void> Function(String, bool) onToggle;

  const _ItemRow({required this.item, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return AppBigRow(
      key: ValueKey('mcp_item_${item.name}'),
      name: item.name,
      description: item.description,
      dot: true,
      dotColor: item.enabled ? null : Colors.transparent,
      actions: [
        AppSwitch(
          value: item.enabled,
          onChanged: (v) => onToggle(item.name, v),
          size: SwitchSize.md,
        ),
      ],
    );
  }
}
