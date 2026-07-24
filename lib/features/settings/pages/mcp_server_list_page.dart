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
  final ValueChanged<McpServerInfo> onServerTap;
  final VoidCallback? onAddServer;

  const McpServerListPage({
    super.key,
    required this.onServerTap,
    this.onAddServer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(configFileStoreProvider);
    final refreshKey = useState(0);

    final data = store.readAll();
    final servers = loadMcpServers(data);
    final enabled = servers.where((s) => !s.disabled).toList();
    final disabled = servers.where((s) => s.disabled).toList();
    final total = servers.length;

    void toggleDisabled(McpServerInfo server, bool value) {
      final idx = servers.indexWhere((s) => s.name == server.name);
      if (idx == -1) return;
      // value 来自 AppSwitch.onChanged（!value），需要取反得到实际的 disabled 状态
      final updated = server.copyWith(disabled: !value);
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
                onToggle: (v) => toggleDisabled(s, v),
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
                onToggle: (v) => toggleDisabled(s, v),
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
      description: server.displayLabel,
      icon: 'server',
      dot: true,
      dotColor: server.disabled ? Colors.transparent : null,
      clickable: true,
      onTap: onTap,
      actions: [
        AppSwitch(
          value: !server.disabled,
          onChanged: onToggle,
          size: SwitchSize.sm,
        ),
      ],
    );
  }
}
