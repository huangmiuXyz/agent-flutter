/// MCP 服务器配置数据模型
///
/// 对应 config.json 中的 `mcpServers` map。
library;

/// 单个 MCP Server 配置。
class McpServerInfo {
  final String name;
  final String command; // stdio 模式
  final List<String> args; // stdio 模式
  final Map<String, String> env; // stdio 模式
  final String url; // HTTP 模式
  final Map<String, String> headers; // HTTP 模式
  final bool disabled; // 设为 true 则跳过
  final List<String> disabledTools;
  final List<String> disabledResources;

  /// 工具权限：工具短名 → default（"ask" / "allow"）。
  /// 持久化到本服务器配置的 `tool_permissions.tools`（MCP 工具权限
  /// 不放在顶层 tool_permissions，随服务器配置走）。
  final Map<String, String> toolPermissions;

  /// [command] 不为空时为 stdio 模式，否则为 http 模式。
  const McpServerInfo({
    required this.name,
    this.command = '',
    this.args = const [],
    this.env = const {},
    this.url = '',
    this.headers = const {},
    this.disabled = false,
    this.disabledTools = const [],
    this.disabledResources = const [],
    this.toolPermissions = const {},
  });

  /// 是否 stdio 模式
  bool get isStdio => command.isNotEmpty;

  /// 显示用的描述。
  String get displayLabel {
    if (isStdio) {
      final parts = [command, ...args];
      return parts.join(' ');
    }
    return url;
  }

  /// 序列化为标准格式的 value（不含 name，name 是 map 的 key）。
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    if (isStdio) {
      result['command'] = command;
      result['args'] = args;
      result['env'] = env;
    } else {
      result['url'] = url;
      result['headers'] = headers;
    }
    if (disabled) {
      result['disabled'] = true;
    }
    if (disabledTools.isNotEmpty) {
      result['disabledTools'] = disabledTools;
    }
    if (disabledResources.isNotEmpty) {
      result['disabledResources'] = disabledResources;
    }
    if (toolPermissions.isNotEmpty) {
      result['tool_permissions'] = {
        'tools': {
          for (final e in toolPermissions.entries) e.key: {'default': e.value},
        },
      };
    }
    return result;
  }

  /// 从标准格式的 value 反序列化。
  /// [name] 从 map 的 key 传入。
  factory McpServerInfo.fromJson(String name, Map<String, dynamic> json) {
    final command = json['command'] as String? ?? '';
    final disabled = json['disabled'] as bool? ?? false;
    final disabledTools =
        (json['disabledTools'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final disabledResources =
        (json['disabledResources'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    // 工具权限：tool_permissions.tools.<工具名>.default
    final toolPermissions = <String, String>{};
    final permTools =
        json['tool_permissions']?['tools'] as Map<String, dynamic>?;
    if (permTools != null) {
      for (final e in permTools.entries) {
        final cfg = e.value as Map<String, dynamic>?;
        final def = cfg?['default'] as String?;
        if (e.key.isNotEmpty && def != null) {
          toolPermissions[e.key] = def;
        }
      }
    }

    if (command.isNotEmpty) {
      return McpServerInfo(
        name: name,
        command: command,
        args:
            (json['args'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        env:
            (json['env'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v.toString()),
            ) ??
            {},
        disabled: disabled,
        disabledTools: disabledTools,
        disabledResources: disabledResources,
        toolPermissions: toolPermissions,
      );
    }
    return McpServerInfo(
      name: name,
      url: json['url'] as String? ?? '',
      headers:
          (json['headers'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          {},
      disabled: disabled,
      disabledTools: disabledTools,
      disabledResources: disabledResources,
      toolPermissions: toolPermissions,
    );
  }

  McpServerInfo copyWith({
    String? name,
    String? command,
    List<String>? args,
    Map<String, String>? env,
    String? url,
    Map<String, String>? headers,
    bool? disabled,
    List<String>? disabledTools,
    List<String>? disabledResources,
    Map<String, String>? toolPermissions,
  }) => McpServerInfo(
    name: name ?? this.name,
    command: command ?? this.command,
    args: args ?? this.args,
    env: env ?? this.env,
    url: url ?? this.url,
    headers: headers ?? this.headers,
    disabled: disabled ?? this.disabled,
    disabledTools: disabledTools ?? this.disabledTools,
    disabledResources: disabledResources ?? this.disabledResources,
    toolPermissions: toolPermissions ?? this.toolPermissions,
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

// ─── 配置文件读写 ─────────────────────────────────────

/// 从 config.json 读取所有 MCP Server 配置。
List<McpServerInfo> loadMcpServers(Map<String, dynamic> data) {
  // 兼容默认配置里的空数组写法（`mcpServers: []`）：
  // 此时按“无服务器”处理，避免 List→Map 强转崩溃。
  final raw = data['mcpServers'];
  final map = switch (raw) {
    List() => <String, dynamic>{},
    Map() => Map<String, dynamic>.from(raw),
    _ => <String, dynamic>{},
  };
  return map.entries
      .map(
        (e) => McpServerInfo.fromJson(e.key, e.value as Map<String, dynamic>),
      )
      .toList();
}

/// 将 MCP Server 列表写回 config.json。
void saveMcpServers(Map<String, dynamic> data, List<McpServerInfo> servers) {
  data['mcpServers'] = {for (final s in servers) s.name: s.toJson()};
}
