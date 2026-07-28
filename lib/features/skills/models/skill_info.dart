/// 技能数据模型
library;

/// 技能来源
class SkillSource {
  final String id;
  final String name;
  const SkillSource(this.id, this.name);

  static const claude = SkillSource('claude', 'Claude Code');
  static const cursor = SkillSource('cursor', 'Cursor');
  static const copilot = SkillSource('copilot', 'GitHub Copilot');
  static const windsurf = SkillSource('windsurf', 'Windsurf');
  static const cline = SkillSource('cline', 'Cline');
  static const codex = SkillSource('codex', 'Codex');
  static const zed = SkillSource('zed', 'Zed');
  static const codebuddy = SkillSource('codebuddy', 'CodeBuddy');
  static const opencode = SkillSource('opencode', 'OpenCode');
  static const roo = SkillSource('roo', 'Roo Code');
  static const agents = SkillSource('agents', 'Agent Skills');
}

/// 技能信息
class SkillInfo {
  final String id;
  final String name;
  final String description;
  final String content;
  final SkillSource source;
  final String scope;
  final String directoryPath;
  final bool enabled;

  const SkillInfo({
    required this.id,
    required this.name,
    required this.description,
    this.content = '',
    required this.source,
    this.scope = 'project',
    required this.directoryPath,
    this.enabled = false,
  });

  SkillInfo copyWith({
    String? id,
    String? name,
    String? description,
    String? content,
    SkillSource? source,
    String? scope,
    String? directoryPath,
    bool? enabled,
  }) => SkillInfo(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    content: content ?? this.content,
    source: source ?? this.source,
    scope: scope ?? this.scope,
    directoryPath: directoryPath ?? this.directoryPath,
    enabled: enabled ?? this.enabled,
  );
}

