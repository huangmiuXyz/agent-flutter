/// MCP 服务器配置数据模型
///
/// 对应 config.json 中的 `mcp_servers` 数组。
library;

/// 单个 MCP Server 配置。
class McpServerInfo {
  final String name;
  final String transportType; // 'stdio' | 'http'
  final String command; // stdio 模式
  final List<String> args; // stdio 模式
  final String url; // HTTP 模式
  final bool enabled;

  const McpServerInfo({
    required this.name,
    this.transportType = 'stdio',
    this.command = '',
    this.args = const [],
    this.url = '',
    this.enabled = true,
  });

  /// 显示用的传输方式描述。
  String get transportLabel {
    if (transportType == 'http') return url;
    final parts = [command, ...args];
    if (parts.isEmpty) return 'stdio';
    return 'stdio: ${parts.join(' ')}';
  }

  /// 简短的传输方式标签。
  String get transportTag =>
      transportType == 'http' ? 'HTTP' : 'STDIO';

  Map<String, dynamic> toJson() => {
    'name': name,
    'transport': {
      'type': transportType,
      if (transportType == 'stdio') ...{
        'command': command,
        'args': args,
      },
      if (transportType == 'http') ...{
        'url': url,
      },
    },
    'enabled': enabled,
  };

  factory McpServerInfo.fromJson(Map<String, dynamic> json) {
    final transport = json['transport'] as Map<String, dynamic>? ?? {};
    return McpServerInfo(
      name: json['name'] as String? ?? '',
      transportType: transport['type'] as String? ?? 'stdio',
      command: transport['command'] as String? ?? '',
      args: (transport['args'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      url: transport['url'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  McpServerInfo copyWith({
    String? name,
    String? transportType,
    String? command,
    List<String>? args,
    String? url,
    bool? enabled,
  }) =>
      McpServerInfo(
        name: name ?? this.name,
        transportType: transportType ?? this.transportType,
        command: command ?? this.command,
        args: args ?? this.args,
        url: url ?? this.url,
        enabled: enabled ?? this.enabled,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is McpServerInfo &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

// ─── 配置文件读写（临时方案，后续由 Rust 后端接管） ────────────

/// 从 config.json 读取所有 MCP Server 配置。
List<McpServerInfo> loadMcpServers(Map<String, dynamic> data) {
  final list = data['mcp_servers'] as List<dynamic>?;
  if (list == null) return [];
  return list
      .map((e) => McpServerInfo.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// 将 MCP Server 列表写回 config.json。
void saveMcpServers(Map<String, dynamic> data, List<McpServerInfo> servers) {
  data['mcp_servers'] = servers.map((s) => s.toJson()).toList();
}
