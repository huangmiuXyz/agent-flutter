/// 智能体数据模型（UI 层）
///
/// 与 Rust 端 `AgentSummary` 对应，但只保留 UI 需要的字段。
library;

/// 全局智能体的固定 ID（根 config.json）
const kGlobalAgentId = '__global__';

class AgentInfo {
  /// 唯一标识（文件夹名），`__global__` 表示全局智能体
  final String id;

  /// 显示名称
  final String name;

  /// 描述
  final String description;

  /// 配置文件的绝对路径
  final String configPath;

  /// 智能体目录的绝对路径（删除等操作用）
  final String directoryPath;

  /// 是否为全局智能体
  final bool isGlobal;

  const AgentInfo({
    required this.id,
    required this.name,
    this.description = '',
    required this.configPath,
    this.directoryPath = '',
    this.isGlobal = false,
  });
}
