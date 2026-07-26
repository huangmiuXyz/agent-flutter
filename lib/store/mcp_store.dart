/// MCP Server 状态管理 — 响应式信号驱动
///
/// 提供基于 [ConfigStore] 的响应式 MCP 服务器列表，
/// 封装 CRUD 操作，替换原来散落在页面中的直接 config 读写。
library;

import 'package:signals/signals.dart';

import 'package:agent/features/settings/models/mcp_server_info.dart';
import 'package:agent/store/config_store.dart';

class McpStore {
  static final instance = McpStore._();
  McpStore._();

  // ── 响应式信号 ──

  /// 所有 MCP 服务器列表（从 ConfigStore 衍生，自动更新）
  final servers = computed<List<McpServerInfo>>(() {
    final data = ConfigStore.instance.data.value;
    final map = data['mcpServers'] as Map<String, dynamic>?;
    if (map == null) return [];
    return map.entries
        .map(
          (e) => McpServerInfo.fromJson(e.key, e.value as Map<String, dynamic>),
        )
        .toList();
  });

  /// 已启用的服务器
  late final enabledServers = computed(
    () => servers.value.where((s) => !s.disabled).toList(),
  );

  /// 已禁用的服务器
  late final disabledServers = computed(
    () => servers.value.where((s) => s.disabled).toList(),
  );

  // ── 操作 ──

  /// 添加 MCP 服务器
  void add(McpServerInfo server) {
    ConfigStore.instance.mutate((data) {
      final list = _loadFrom(data);
      list.add(server);
      _saveTo(data, list);
    });
  }

  /// 更新指定名称的 MCP 服务器
  void update(String name, McpServerInfo updated) {
    ConfigStore.instance.mutate((data) {
      final list = _loadFrom(data);
      final idx = list.indexWhere((s) => s.name == name);
      if (idx != -1) list[idx] = updated;
      _saveTo(data, list);
    });
  }

  /// 删除指定名称的 MCP 服务器
  void remove(String name) {
    ConfigStore.instance.mutate((data) {
      final list = _loadFrom(data);
      list.removeWhere((s) => s.name == name);
      _saveTo(data, list);
    });
  }

  /// 切换启用/禁用状态
  void toggleEnabled(String name, bool enabled) {
    ConfigStore.instance.mutate((data) {
      final list = _loadFrom(data);
      final idx = list.indexWhere((s) => s.name == name);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(disabled: !enabled);
      }
      _saveTo(data, list);
    });
  }

  // ── 内部 ──

  static List<McpServerInfo> _loadFrom(Map<String, dynamic> data) {
    final map = data['mcpServers'] as Map<String, dynamic>?;
    if (map == null) return [];
    return map.entries
        .map(
          (e) => McpServerInfo.fromJson(e.key, e.value as Map<String, dynamic>),
        )
        .toList();
  }

  static void _saveTo(Map<String, dynamic> data, List<McpServerInfo> servers) {
    data['mcpServers'] = {for (final s in servers) s.name: s.toJson()};
  }
}
