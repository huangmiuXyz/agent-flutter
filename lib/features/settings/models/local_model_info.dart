/// 本地模型数据模型 — 对应 config.json 的 `local_models` 段。
///
/// 每条记录描述一个设备端 GGUF 模型：显示名、文件路径、上下文长度。
/// 相关配置：
/// - `local_models`: `[{name, path, contextSize}]` 模型列表
/// - `language_models.openai_compatible.local_llm`: 由 [LocalModelService]
///   在服务启动时自动维护的 provider 段（指向 127.0.0.1 内嵌服务）
library;

class LocalModelInfo {
  final String name;
  final String path;
  final int contextSize;

  /// 最大生成 token 数（思考内容也计入）。null = 使用服务端默认。
  final int? maxTokens;

  /// 是否激活（启用）。未激活的模型不会出现在「运行模型」选择中。
  final bool enabled;

  const LocalModelInfo({
    required this.name,
    required this.path,
    this.contextSize = 4096,
    this.maxTokens,
    this.enabled = true,
  });

  factory LocalModelInfo.fromJson(Map<String, dynamic> json) => LocalModelInfo(
    name: (json['name'] as String?) ?? '',
    path: (json['path'] as String?) ?? '',
    contextSize: (json['contextSize'] as num?)?.toInt() ?? 4096,
    maxTokens: (json['maxTokens'] as num?)?.toInt(),
    enabled: (json['enabled'] as bool?) ?? true,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'contextSize': contextSize,
    if (maxTokens != null) 'maxTokens': maxTokens,
    'enabled': enabled,
  };

  /// 显示名（不含扩展名的文件名，可后续编辑）。
  String get label => name;

  /// 供 model 选择器使用的模型 ID（与 /v1/models 返回一致）。
  String get modelId => name;
}
