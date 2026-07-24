/// MCP 服务器列表页 — 展示所有已配置的 MCP Server。
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/features/settings/models/mcp_server_info.dart';
import 'package:agent/services/config_service.dart';
import 'package:agent/utils/file_utils.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/list/app_big_list.dart';
import 'package:agent/widgets/switch/app_switch.dart';

/// MCP 服务器列表页。
class McpServerListPage extends HookConsumerWidget {
  /// 点击某一行进入编辑页。
  final ValueChanged<McpServerInfo> onServerTap;

  /// 点击"添加服务器"。
  final VoidCallback? onAddServer;

  const McpServerListPage({
    super.key,
    required this.onServerTap,
    this.onAddServer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(configFileStoreProvider);
    // 用 useState 触发刷新（修改后重建）
    final refreshKey = useState(0);

    final data = store.readAll();
    final servers = loadMcpServers(data);
    final enabled = servers.where((s) => s.enabled).toList();
    final disabled = servers.where((s) => !s.enabled).toList();
    final total = servers.length;

    // 切换启用状态
    void toggleEnabled(McpServerInfo server, bool value) {
      final idx = servers.indexWhere((s) => s.name == server.name);
      if (idx == -1) return;
      final updated = server.copyWith(enabled: value);
      final copy = [...servers];
      copy[idx] = updated;
      saveMcpServers(data, copy);
      store.writeAll(data);
      refreshKey.value++;
    }

    final groups = <Widget>[];
    if (enabled.isNotEmpty) {
      groups.add(
        AppBigGroup(
          label: '已启用',
          children: [
            for (final s in enabled)
              _ServerRow(
                server: s,
                onTap: () => onServerTap(s),
                onToggle: (v) => toggleEnabled(s, v),
              ),
          ],
        ),
      );
    }
    if (disabled.isNotEmpty) {
      groups.add(
        AppBigGroup(
          label: '已禁用',
          children: [
            for (final s in disabled)
              _ServerRow(
                server: s,
                onTap: () => onServerTap(s),
                onToggle: (v) => toggleEnabled(s, v),
              ),
          ],
        ),
      );
    }

    return ContentFrame(
      child: AppBigList(
        key: ValueKey('mcp_list_$refreshKey'),
        count: total,
        countLabel: '个服务器',
        showSearch: false,
        actions: [
          AppPrimaryButton(
            text: '添加服务器',
            size: ButtonSize.sm,
            onPressed: onAddServer,
          ),
          const SizedBox(width: 8),
          AppSecondaryButton(
            text: '配置文件',
            icon: 'fileCode',
            size: ButtonSize.sm,
            onPressed: () => openFile(store.configPath),
          ),
        ],
        emptyState: AppBigEmpty(
          icon: 'server',
          title: '暂无 MCP 服务器',
          hint: '添加服务器后，Agent 启动时将自动连接。',
        ),
        children: groups,
      ),
    );
  }
}

/// MCP 服务器列表中的一行。
class _ServerRow extends HookWidget {
  final McpServerInfo server;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  const _ServerRow({
    required this.server,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AppBigRow(
      name: server.name,
      description: server.transportLabel,
      icon: 'server',
      dot: true,
      dotColor: server.enabled ? null : Colors.transparent,
      clickable: true,
      onTap: onTap,
      actions: [
        AppSwitch(
          value: server.enabled,
          onChanged: onToggle,
          size: SwitchSize.sm,
        ),
      ],
    );
  }
}

