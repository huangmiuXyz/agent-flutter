/// 智能体配置导入辅助函数。
library;

/// 从全局 config.json 提取可选的配置片段，供创建/编辑智能体时使用。
///
/// 返回一个 map，只包含 UI 上允许用户选择的字段：
/// - default_model
/// - mcpServers
/// - skills
Map<String, dynamic> extractImportableConfig(Map<String, dynamic> globalConfig) {
  final result = <String, dynamic>{};

  if (globalConfig.containsKey('default_model')) {
    result['default_model'] = globalConfig['default_model'];
  }
  if (globalConfig.containsKey('mcpServers')) {
    result['mcpServers'] = globalConfig['mcpServers'];
  }
  if (globalConfig.containsKey('skills')) {
    result['skills'] = globalConfig['skills'];
  }

  return result;
}
