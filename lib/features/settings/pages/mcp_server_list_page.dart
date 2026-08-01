/// MCP 服务器列表页 — 展示所有已配置的 MCP Server。
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/settings/models/mcp_server_info.dart';
import 'package:agent/store/config_store.dart';
import 'package:agent/utils/file_utils.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/list/app_big_list.dart';
import 'package:agent/widgets/list/toggle_group_list.dart';
import 'package:agent/widgets/switch/app_switch.dart';

/// MCP 服务器列表页。
class McpServerListPage extends HookWidget {
  final ValueChanged<McpServerInfo> onServerTap;
  final VoidCallback? onAddServer;

  const McpServerListPage({
    super.key,
    required this.onServerTap,
    this.onAddServer,
  });

  @override
  Widget build(BuildContext context) {
    final store = ConfigStore.instance;

    // 订阅 data 信号变化，确保 toggle / 增删改后立即重建
    final data = useExistingSignal(store.data).value;
    final servers = loadMcpServers(data);

    void toggleDisabled(McpServerInfo server, bool enabled) {
      store.updateMcpServers((list) {
        final idx = list.indexWhere((s) => s.name == server.name);
        if (idx != -1) list[idx] = list[idx].copyWith(disabled: !enabled);
      });
    }

    return ToggleGroupListPage<McpServerInfo>(
      key: ValueKey('mcp_list_${store.data.value}'),
      items: servers,
      isEnabled: (s) => !s.disabled,
      countLabel: '个服务器',
      rowBuilder: (context, s) => _ServerRow(
        server: s,
        onTap: () => onServerTap(s),
        onToggle: (v) => toggleDisabled(s, v),
      ),
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
