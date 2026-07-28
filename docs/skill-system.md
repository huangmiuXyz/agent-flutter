# 技能系统开发文档

## 概述

技能系统让 Agent 能够发现、管理和使用 AI 编程助手的技能文件。技能是一份 Markdown 格式的领域知识/工作流程说明，Agent 在对话中根据上下文按需加载并使用。

### 设计原则

1. **按需加载** — system prompt 只注入技能目录（name + description），完整内容由 LLM 通过 `load_skill` tool 按需获取
2. **跨工具兼容** — 支持扫描市面上主流 AI 编程工具的技能目录
3. **用户可控** — 用户可以在设置页面浏览所有发现的技能，并启用/禁用
4. **后端扫描** — 文件扫描在 Rust 侧完成，Flutter 通过 FRB 调用，CLI 也可复用

### 与其他工具的关系

| 概念 | 本系统 | 备注 |
|------|--------|------|
| 技能发现 | `SkillScanner.scan()` | 扫描所有已知目录 |
| 启禁状态 | `ConfigStore.updateSkills()` | 持久化到 `config.json` |
| 注入 catalog | `buildSkillCatalog()` | name + description 列表 |
| 按需加载 | `load_skill` tool | LLM 通过 tool calling 获取全文 |

---

## 技能文件格式

所有工具的技能文件格式统一：**SKILL.md**，位于技能名称目录下。

### 目录结构

```
<skills-dir>/
├── my-skill/
│   ├── SKILL.md          # 必需
│   └── 其他支持文件       # 可选（模板、脚本等）
└── another-skill/
    └── SKILL.md
```

### SKILL.md 格式

```markdown
---
name: my-skill
description: 清晰描述这个技能的作用和何时使用。
---

# 技能名称

技能的具体指导内容...
```

### YAML Frontmatter 字段

| 字段 | 必需 | 说明 |
|------|------|------|
| `name` | 是 | 技能唯一标识符，全小写字母+数字+连字符，1-64字符 |
| `description` | 是 | 技能描述，1-1024字符，LLM 根据此字段决定是否加载技能 |

---

## 所有已知技能目录

本应用尚无工作目录概念，当前仅支持全局技能（用户目录）。

### 全局（用户目录）

| 工具 | 目录 |
|------|------|
| Claude Code | `~/.claude/skills/` |
| Cursor | `~/.cursor/skills/` |
| Cursor（兼容） | `~/.agents/skills/` |
| GitHub Copilot | `~/.copilot/skills/` |
| GitHub Copilot（兼容） | `~/.agents/skills/` |
| Windsurf | `~/.codeium/windsurf/skills/` |
| Cline | `~/.cline/skills/` |
| Codex | `~/.agents/skills/` |
| Zed | `~/.config/zed/agents/skills/` |
| CodeBuddy | `~/.codebuddy/skills/` |
| Roo Code | `~/.roo/skills/` |

### 去重

同名技能以先扫描到的为准。

---

## 数据流程

```
┌─────────────────────────────────────────────────────┐
│ 应用启动                                              │
│                                                     │
│  1. Rust scan_global_skills()                          │
│     ├── 遍历 ~/.claude/skills/ 等已知目录               │
│     ├── 解析每个 SKILL.md 的 frontmatter                │
│     └── 返回 List<SkillInfo>（仅 name + description）   │
│     └── Flutter 通过 FRB 获取扫描结果                    │
│                                                     │
│  2. SkillStore 接收扫描结果                            │
│     ├── 与 ConfigStore 中的启禁状态合并                  │
│     └── skills 信号就绪 → UI 渲染列表                   │
│                                                     │
│  3. 用户发消息                                        │
│     └── buildSkillCatalog() → 注入到 system prompt     │
│           ↓                                           │
│  4. LLM 判断需要某个技能                                │
│     └── 调 load_skill(skill_id) tool                  │
│           ↓                                           │
│  5. handleLoadSkill 读取 SKILL.md 全文并返回            │
└─────────────────────────────────────────────────────┘
```

---

## 模块划分

### Rust 后端 — `agent-flutter-cli/src/api/skills.rs`

```rust
/// 扫描全局目录，返回发现的技能列表。
/// 只解析 frontmatter（name + description），不读正文。
pub fn scan_global_skills() -> Vec<SkillInfo> {
    let home = dirs::home_dir();
    // 遍历 ~/.claude/skills/ 等所有已知目录
    // 解析 SKILL.md 的 YAML frontmatter
    // 返回 SkillInfo 列表
}

/// 读取指定技能目录下的 SKILL.md 全文。
/// LLM 通过 load_skill tool 按需调用。
pub fn load_skill_content(directory_path: String) -> String {
    let path = Path::new(&directory_path).join("SKILL.md");
    std::fs::read_to_string(path).unwrap_or_default()
}
```

Flutter 通过 FRB 调用 `scan_global_skills()` 和 `load_skill_content()`。

### `features/skills/store/skill_store.dart`

```dart
class SkillStore {
  static final instance = SkillStore._();

  /// 所有技能（信号）
  final skills = signal(<String, SkillInfo>{});

  /// 仅启用的技能
  late final enabledSkills = computed(() {
    final states = ConfigStore.instance.loadSkillStates(ConfigStore.instance.data.value);
    return skills.value.values.where((s) => states[s.id] ?? s.enabled).toList();
  });

  /// 加载扫描结果，与 ConfigStore 启禁状态合并
  void load(List<SkillInfo> discovered) { ... }

  /// 按 id 查找技能
  SkillInfo? findById(String id) { ... }
}
```

### `store/config_store.dart`（已实现）

```dart
// 已有接口：
void updateSkills(void Function(Map<String, bool>) fn);
Map<String, bool> loadSkillStates(Map<String, dynamic> data);

// config.json 格式：
// "skills": {
//   "my-skill": { "enabled": true },
//   "another-skill": { "enabled": false }
// }
```

### 注入到 System Prompt

在构建 system prompt 时调用：

```dart
String buildSkillCatalog() {
  final skills = SkillStore.instance.enabledSkills.value;
  if (skills.isEmpty) return '';

  return '''
## 可用技能

${skills.map((s) => '- ${s.id}: ${s.description}').join('\n')}

当你需要某个技能的完整指导时，调用 \`load_skill\` 工具加载。
''';
}
```

### `load_skill` 工具

注册方式与 `simulated_terminal` 完全一致：

```dart
// 在 registerFrontendTools() 中注册
void registerLoadSkillTool() {
  LlmService().registerFrontendTool(
    name: 'load_skill',
    description: '加载指定技能的完整内容。skill_id 从 system prompt 的"可用技能"列表中获取。',
    parameters: jsonEncode({
      'type': 'object',
      'properties': {
        'skill_id': {
          'type': 'string',
          'description': '技能的唯一标识符',
        },
      },
      'required': ['skill_id'],
    }),
  );
  EngineClient.instance.registerToolHandler('load_skill', _handleLoadSkill);
}

Future<String> _handleLoadSkill(EngineEvent_FrontendToolCall event) async {
  final args = jsonDecode(event.arguments) as Map<String, dynamic>;
  final skillId = args['skill_id']?.toString();
  if (skillId == null || skillId.isEmpty) {
    return 'Error: missing skill_id';
  }

  final skill = SkillStore.instance.findById(skillId);
  if (skill == null) {
    return 'Error: skill "$skillId" not found';
  }

  // 读取 SKILL.md 全文
  final file = File('${skill.directoryPath}/SKILL.md');
  if (!file.existsSync()) {
    return 'Error: SKILL.md not found at ${skill.directoryPath}';
  }

  return file.readAsStringSync();
}
```

---

## 前端页面

### 技能列表页

- 位置：设置页面 → 左侧边栏"技能" tab
- 和 MCP 服务器列表一致的 UI
- 展示所有已发现的技能（按已启用/已禁用分组）
- 每行显示：图标 + 技能名 + 描述 + 来源标签 + 开关
- 顶部按钮："重新扫描"、"配置文件"

### 技能详情页

- 位置：点击技能进入
- breadcrumb：设置 > 技能 > [技能名] > 详情
- 展示：来源、范围、路径、SKILL.md 正文预览

---

## 验证方法

1. 在 `~/.agents/skills/` 下已有 `scaffold-dev-guide` 和 `chub-search`
2. 启动应用后切换到"技能"设置页，应能看到这两个技能
3. 启用后对话，AI 应能看到"可用技能"列表
4. 当 AI 需要时，应能调用 `load_skill` 加载全文

---
