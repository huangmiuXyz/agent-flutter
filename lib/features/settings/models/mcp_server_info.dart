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

  /// [command] 不为空时为 stdio 模式，否则为 http 模式。
  const McpServerInfo({
    required this.name,
    this.command = '',
    this.args = const [],
    this.env = const {},
    this.url = '',
    this.headers = const {},
    this.disabled = false,
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
    return result;
  }

  /// 从标准格式的 value 反序列化。
  /// [name] 从 map 的 key 传入。
  factory McpServerInfo.fromJson(String name, Map<String, dynamic> json) {
    final command = json['command'] as String? ?? '';
    final disabled = json['disabled'] as bool? ?? false;
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
  }) => McpServerInfo(
    name: name ?? this.name,
    command: command ?? this.command,
    args: args ?? this.args,
    env: env ?? this.env,
    url: url ?? this.url,
    headers: headers ?? this.headers,
    disabled: disabled ?? this.disabled,
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
