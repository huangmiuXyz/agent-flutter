# 智能体系统开发文档

## 概述

智能体系统是应用的核心抽象层，它将**模型配置、MCP 服务器、技能**组合为一个独立的执行单元。用户可以在聊天时选择不同的智能体，以切换对话的行为模式和能力范围。

### 设计原则

1. **配置即文件** — 每个智能体是一个文件夹，`config.json` 是自包含的完整配置，与全局配置无关
2. **全局智能体即根配置** — 根目录 `config.json` 本身就是"全局智能体"，始终存在
3. **零继承** — 选中哪个智能体就用哪个配置，不存在字段级继承或合并
4. **后端驱动** — 智能体的扫描、配置读取由 Rust 后端完成，Flutter 仅负责展示和修改配置
5. **向后兼容** — 不使用智能体时行为与现在完全一致

### 核心概念

| 概念 | 文件 | 说明 |
|------|------|------|
| **全局智能体** | `agent-flutter-cli/config.json` | 默认智能体，始终存在，不依赖 `agents/` 目录 |
| **自定义智能体** | `agent-flutter-cli/agents/<id>/config.json` | 自包含的完整配置，完全独立于全局 |
| **同一套 schema** | config.json 与 agents/*/config.json | 两者字段结构完全相同 |

---

## 目录结构

### agents/ 目录位置

`agents/` 目录始终和 `config.json` 同级，由 Rust 侧从 `config_path` 自动推导：

```rust
fn agents_dir(config_path: &Path) -> PathBuf {
    config_path.parent().unwrap().join("agents")
}
```

```
开发环境：
  config.json = agent-flutter-cli/config.json
  agents/     = agent-flutter-cli/agents/

生产环境（Windows 示例）：
  config.json = %APPDATA%/agent/config.json
  agents/     = %APPDATA%/agent/agents/
```

目录结构：

```
agent-qi/
├── agent-flutter-cli/              # 后端 Rust 项目（含 config.json）
│   ├── config.json                 # ← 全局智能体配置
│   ├── agents/                     # ← 自定义智能体根目录
│   │   ├── code-reviewer/
│   │   │   └── config.json         #    自包含完整配置
│   │   ├── data-analyst/
│   │   │   └── config.json
│   │   └── translator/
│   │       └── config.json
│   ├── src/
│   └── ...
├── agent-flutter/                  # 前端 Flutter 项目
└── ...
```

### 智能体 config.json 格式

与根目录 `config.json` 使用完全相同的 schema，一个自包含的独立配置：

```jsonc
{
  "provider": ["deepseek", "openai"],
  "default_model": {
    "provider": "deepseek",
    "model": "deepseek-v4-flash"
  },
  "work_dir": "E:/code/private/agent-qi",
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
    }
  },
  "skills": {
    "context7": { "enabled": true },
    "create-skill": { "enabled": false }
  },
  "language_models": {
    "openai_compatible": {
      "deepseek": {
        "api_key": "sk-xxx",
        "api_url": "https://api.deepseek.com/v1",
        "available_models": [
          { "name": "deepseek-v4-flash" },
          { "name": "deepseek-v4-pro" }
        ]
      }
    }
  }
}
```

字段定义参见 [`config.schema.json`](../agent-flutter-cli/config.schema.json)（与 `config.json` 同目录）。

---

## 数据流程

```
┌──────────────────────────────────────────────────────────────┐
│ 应用启动 / 用户进入智能体设置                                  │
│                                                              │
│  1. Rust list_agents()                                        │
│     ├── 虚拟的"全局智能体"项（始终存在）                       │
│     └── 扫描 agents/ 目录下每个子目录的 config.json            │
│         └── 返回 Vec<AgentSummary>                            │
│                                                              │
│  2. Flutter AgentStore 接收扫描结果                           │
│     ├── agents 信号就绪 → 智能体选择器渲染                    │
│     └── 选中"全局智能体" → 使用 ConfigStore.data              │
│                                                              │
│  3. 用户在聊天页选择智能体                                    │
│     ├── 全局智能体 → 传 agent-flutter-cli/config.json 路径    │
│     └── 自定义智能体 → 传 agent-flutter-cli/agents/<id>/config.json 路径 │
│                                                              │
│  4. Rust chat_stream 读取传入路径的配置文件                    │
│     ├── 读取 mcpServers → 初始化对应的 MCP 客户端             │
│     ├── 读取 skills → 注入 system prompt                     │
│     └── 读取 default_model → 选择 LLM 提供商                  │
│                                                              │
│  5. LLM 响应通过 engine::publish 返回 Flutter                 │
└──────────────────────────────────────────────────────────────┘
```

### 聊天时配置路径传递

```dart
// 全局智能体 → 传 config.json 的路径
bridge.chatStream(
  configPath: configStore.configPath,  // 指向根 config.json
  provider: ...,
  model: ...,
  prompt: ...,
  ...
);

// 自定义智能体 → 传 agent-flutter-cli/agents/xxx/config.json 的路径
bridge.chatStream(
  configPath: agentConfigPath,         // 指向 agent-flutter-cli/agents/xxx/config.json
  provider: ...,
  model: ...,
  prompt: ...,
  ...
);
```

Rust 侧唯一变化：`chat_stream` 接受的 `config_path` 不再固定为根目录 `config.json`，而是由 Flutter 端根据选中的智能体动态传入。读取配置文件后的所有逻辑不变。

---

## 页面结构

```
设置页（SettingsPage）
├── 侧边栏: [高级] [模型提供商] [MCP 服务器] [技能] [智能体]
└── 右侧内容区:
    ├── 智能体列表页 (AgentListPage)
    │   ├── "全局智能体"（置顶，始终显示）
    │   ├── 自定义智能体列表（卡片式）
    │   │   ├── 名称、描述、模型信息
    │   │   ├── 已启用技能数、MCP 服务器数
    │   │   └── 点击进入编辑 / 删除
    │   └── "+ 创建智能体" 按钮
    │
    └── 智能体编辑页 (AgentEditPage)
        ├── 基本信息（名称、描述、头像）
        ├── default_model（`AppSelect` 从全局已有模型列表中选择）
        ├── MCP 服务器（`AppMultiSelect` 从全局已有 mcpServers 列表中勾选）
        ├── 技能启禁（`AppMultiSelect` 从已扫描到的全局技能中勾选）
        ├── work_dir（可选）
        └── [保存] [从全局导入] [重置]
```

### 聊天页改动

在消息输入框上方添加智能体选择器（DropdownButton）：

```
┌─────────────────────────────────────────┐
│ [ 全局智能体 ▾ ]                        │
│  ┌─────────────────────┐                │
│  │ ✓ 全局智能体         │                │
│  │ ─────────────────── │                │
│  │   代码审查助手       │                │
│  │   数据分析师         │                │
│  │   翻译专家           │                │
│  └─────────────────────┘                │
│                                         │
│  消息输入...                   [发送]   │
└─────────────────────────────────────────┘
```

---

## 后端设计 — Rust `agent` 模块

### 模块结构

```
agent-flutter-cli/src/
├── agent/                           # ← 新增：智能体系统
│   ├── mod.rs                       #   模块导出、错误类型
│   └── registry.rs                  #   智能体扫描与读取
├── api/
│   └── mod.rs                       #   + list_agents / read_agent_config / write_agent_config / create_agent / delete_agent
└── ...
```

### 核心数据结构

```rust
// agent/mod.rs

/// 智能体摘要（列表用，不含配置正文）
#[derive(Debug, Clone, Serialize)]
pub struct AgentSummary {
    /// 智能体唯一标识（文件夹名），全局智能体为 "__global__"
    pub id: String,
    /// 显示名称
    pub name: String,
    /// 描述
    pub description: String,
    /// 配置文件的绝对路径
    pub config_path: String,
    /// 是否为全局智能体（根 config.json）
    pub is_global: bool,
}
```

### 扫描实现

```rust
// agent/registry.rs

/// 从 config_path 推导 agents/ 目录
fn agents_dir(config_path: &Path) -> PathBuf {
    config_path.parent().unwrap().join("agents")
}

/// 列出所有智能体（全局智能体 + agents/ 下的自定义智能体）
pub fn list_agents(config_path: &Path) -> Vec<AgentSummary> {
    let mut results = Vec::new();

    // 1. 虚拟的"全局智能体"（始终存在）
    if config_path.exists() {
        if let Some(summary) = read_agent_summary(config_path, "__global__", true) {
            results.push(summary);
        }
    }

    // 2. 扫描 agents/ 目录
    let agents_dir = agents_dir(config_path);
    if !agents_dir.is_dir() {
        return results;
    }

    let entries = match fs::read_dir(&agents_dir) {
        Ok(e) => e,
        Err(_) => return results,
    };
    for entry in entries.flatten() {
        let dir = entry.path();
        if !dir.is_dir() {
            continue;
        }
        let agent_cfg_path = dir.join("config.json");
        if !agent_cfg_path.exists() {
            continue;
        }
        let id = dir.file_name()?.to_string_lossy().to_string();
        if let Some(summary) = read_agent_summary(&agent_cfg_path, &id, false) {
            results.push(summary);
        }
    }

    results
}

fn read_agent_summary(
    config_path: &Path,
    id: &str,
    is_global: bool,
) -> Option<AgentSummary> {
    let root = config::read_config_json(config_path).ok()?;
    let name = root.get("name")
        .and_then(|v| v.as_str())
        .unwrap_or(id)
        .to_string();
    let description = root.get("description")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();

    Some(AgentSummary {
        id: id.to_string(),
        name,
        description,
        config_path: config_path.to_string_lossy().to_string(),
        is_global,
    })
}
```

### 配置读写

```rust
/// 读取智能体配置全文（JSON string）
pub fn read_agent_config(config_path: &str) -> Result<String, String> {
    let content = fs::read_to_string(config_path)
        .map_err(|e| format!("读取失败: {e}"))?;
    Ok(content)
}

/// 写入智能体配置
pub fn write_agent_config(config_path: &str, config_json: &str) -> Result<(), String> {
    // 校验 JSON 合法性
    let _: Value = serde_json::from_str(config_json)
        .map_err(|e| format!("JSON 格式错误: {e}"))?;
    let path = Path::new(config_path);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .map_err(|e| format!("创建目录失败: {e}"))?;
    }
    fs::write(path, config_json)
        .map_err(|e| format!("写入失败: {e}"))?;
    Ok(())
}
```

### 创建与删除

```rust
/// 创建智能体
/// config_path 传全局 config.json 路径，用于推导 agents/ 目录
pub fn create_agent(
    config_path: &Path,
    id: &str,
    config_json: &str,
) -> Result<AgentSummary, String> {
    let agent_dir = agents_dir(config_path).join(id);
    if agent_dir.exists() {
        return Err(format!("智能体「{id}」已存在"));
    }

    fs::create_dir_all(&agent_dir)
        .map_err(|e| format!("创建目录失败: {e}"))?;

    let agent_cfg_path = agent_dir.join("config.json");
    write_agent_config(
        &agent_cfg_path.to_string_lossy(),
        config_json,
    )?;

    read_agent_summary(&agent_cfg_path, id, false)
        .ok_or_else(|| "创建成功但读取失败".to_string())
}

/// 删除智能体
/// agent_dir 传智能体目录的绝对路径（来自 AgentSummary.directory_path）
pub fn delete_agent(agent_dir: &str) -> Result<(), String> {
    let path = Path::new(agent_dir);
    if !path.exists() {
        return Err("智能体目录不存在".to_string());
    }
    fs::remove_dir_all(path)
        .map_err(|e| format!("删除失败: {e}"))
}
```

### FRB 导出 API

所有函数只接受 `config_path` 作为路径参数，`agents/` 目录由 Rust 内部推导。

```rust
// api/mod.rs — 新增

/// 列出所有智能体（含虚拟的"全局智能体"）
pub fn list_agents(config_path: String) -> Vec<AgentSummary>;

/// 读取智能体配置全文
pub fn read_agent_config(config_path: String) -> Result<String, String>;

/// 写入智能体配置
pub fn write_agent_config(config_path: String, config_json: String) -> Result<(), String>;

/// 创建智能体
pub fn create_agent(
    config_path: String,     // 全局 config.json 路径，用于推导 agents/ 目录
    agent_id: String,
    config_json: String,
) -> Result<AgentSummary, String>;

/// 删除智能体
pub fn delete_agent(agent_dir: String) -> Result<(), String>;
```

> 注：`AgentSummary` 中需增加 `directory_path` 字段（智能体目录的绝对路径），
> 供删除等操作使用。Flutter 端不自行拼路径，全部由 Rust 返回。

### 配置读写

```rust
/// 读取智能体配置全文（JSON string）
pub fn read_agent_config(config_path: &str) -> Result<String, String> {
    let content = fs::read_to_string(config_path)
        .map_err(|e| format!("读取失败: {e}"))?;
    Ok(content)
}

/// 写入智能体配置
pub fn write_agent_config(config_path: &str, config_json: &str) -> Result<(), String> {
    // 校验 JSON 合法性
    let _: Value = serde_json::from_str(config_json)
        .map_err(|e| format!("JSON 格式错误: {e}"))?;
    let path = Path::new(config_path);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .map_err(|e| format!("创建目录失败: {e}"))?;
    }
    fs::write(path, config_json)
        .map_err(|e| format!("写入失败: {e}"))?;
    Ok(())
}
```

### 创建与删除

```rust
pub fn create_agent(agents_dir: &str, id: &str, config_json: &str) -> Result<AgentSummary, String> {
    let agent_dir = Path::new(agents_dir).join(id);
    if agent_dir.exists() {
        return Err(format!("智能体「{id}」已存在"));
    }

    // 创建目录
    fs::create_dir_all(&agent_dir)
        .map_err(|e| format!("创建目录失败: {e}"))?;

    // 写 config.json
    let config_path = agent_dir.join("config.json");
    write_agent_config(
        &config_path.to_string_lossy(),
        config_json,
    )?;

    // 返回摘要
    read_agent_summary(&config_path, id, false)
        .ok_or_else(|| "创建成功但读取失败".to_string())
}

pub fn delete_agent(agent_dir: &str) -> Result<(), String> {
    let path = Path::new(agent_dir);
    if !path.exists() {
        return Err("智能体目录不存在".to_string());
    }
    fs::remove_dir_all(path)
        .map_err(|e| format!("删除失败: {e}"))
}
```

### FRB 导出 API

```rust
// api/mod.rs — 新增

/// 列出所有智能体
pub fn list_agents(
    config_path: String,       // 根 config.json 路径
    agents_base_dir: String,   // agents/ 目录路径
) -> Vec<AgentSummary>;

/// 读取智能体配置全文
pub fn read_agent_config(config_path: String) -> Result<String, String>;

/// 写入智能体配置
pub fn write_agent_config(config_path: String, config_json: String) -> Result<(), String>;

/// 创建智能体
pub fn create_agent(
    agents_base_dir: String,
    agent_id: String,
    config_json: String,
) -> Result<AgentSummary, String>;

/// 删除智能体
pub fn delete_agent(agent_dir: String) -> Result<(), String>;
```

---

## 前端设计 — Flutter

### 目录结构

```
lib/features/agents/                    # ← 新增
├── models/
│   ├── agent_info.dart                 #   数据模型
│   └── agent_config_helper.dart        #   配置导入辅助函数
├── pages/
│   ├── agent_list_page.dart            #   智能体列表页
│   └── agent_edit_page.dart            #   智能体编辑/创建页
├── store/
│   └── agent_store.dart                #   状态管理
└── widgets/
    └── agent_selector.dart             #   聊天页智能体选择器
```

### 数据模型

```dart
// models/agent_info.dart

class AgentInfo {
  final String id;            // 唯一标识，"__global__" 表示全局智能体
  final String name;          // 显示名称
  final String description;   // 描述
  final String configPath;    // 配置文件的绝对路径
  final bool isGlobal;        // 是否为全局智能体

  const AgentInfo({
    required this.id,
    required this.name,
    this.description = '',
    required this.configPath,
    this.isGlobal = false,
  });
}
```

### 状态管理

```dart
// store/agent_store.dart

class AgentStore {
  static final instance = AgentStore._();
  AgentStore._();

  /// 所有智能体列表（信号，保留顺序）
  final agents = signal(<AgentInfo>[]);

  /// 当前选中的智能体 ID
  final currentAgentId = signal<String>('__global__');

  /// 当前选中的智能体（计算信号）
  late final currentAgent = computed(() {
    return agents.value.where((a) => a.id == currentAgentId.value).firstOrNull;
  });

  /// 当前智能体的配置文件路径
  late final currentConfigPath = computed(() {
    return currentAgent.value?.configPath ?? ConfigStore.instance.configPath;
  });

  /// 加载 Rust 扫描结果
  void load(List<AgentSummary> discovered) {
    agents.value = discovered.map((s) => AgentInfo(
      id: s.id,
      name: s.name,
      description: s.description,
      configPath: s.configPath,
      isGlobal: s.isGlobal,
    )).toList();
  }

  /// 切换到指定智能体
  void select(String id) {
    currentAgentId.value = id;
  }
}
```

### "从全局导入"功能

在智能体编辑页，用户点击"从全局导入"时，把当前全局 `config.json` 的内容填充到编辑器中，作为新智能体配置的起点：

```dart
// models/agent_config_helper.dart

/// 从全局 config.json 提取可选的配置片段，供创建/编辑智能体时使用
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
```

### 智能体编辑页 UI 结构

```
AgentEditPage
├── 基本信息区
│   ├── TextField: 名称（必填）
│   └── TextField: 描述
│
├── default_model 区
│   ├── AppSelect: provider（从全局 model 列表选择）
│   └── AppSelect: model（根据选中的 provider 过滤）
│
├── MCP 服务器区
│   ├── AppMultiSelect: 从全局 mcpServers 列表中勾选
│   └── value: Set<String> 存储已选服务器名
│
├── 技能区
│   ├── AppMultiSelect: 从已扫描的全局技能列表中勾选
│   └── value: Set<String> 存储已启用的技能 ID
│
├── work_dir 区
│   └── TextField: 工作目录
│
└── 底部操作栏
    ├── [从全局导入] → 填充当前表单（覆盖已有内容）
    └── [保存] → 调用 write_agent_config
```

### 智能体选择器

```dart
// widgets/agent_selector.dart

class AgentSelector extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final store = AgentStore.instance;
    final agents = store.agents.value;
    final currentId = store.currentAgentId.value;

    return DropdownButton<String>(
      value: currentId,
      isDense: true,
      onChanged: (id) {
        if (id != null) store.select(id);
      },
      items: [
        for (final agent in agents)
          DropdownMenuItem(
            value: agent.id,
            child: Text(agent.name),
          ),
      ],
    );
  }
}
```

---

## 路由配置

```dart
abstract class AppRoutes {
  static const chat = '/';
  static const settings = '/settings';
  // 智能体管理嵌套在设置页内，不需要独立路由
}
```

智能体管理作为设置页的一个 Tab，与 MCP、技能等平级：

```dart
enum SettingsTab { advanced, models, mcp, skills, agents }
```

---

## 实现步骤

### Phase 1 — Rust 后端：智能体扫描与 CRUD

| # | 文件 | 内容 |
|---|------|------|
| 1 | `src/agent/mod.rs` | `AgentSummary` 结构体、模块导出 |
| 2 | `src/agent/registry.rs` | `list_agents()`、`read_agent_config()`、`write_agent_config()`、`create_agent()`、`delete_agent()` |
| 3 | `src/lib.rs` | 注册 `agent` 模块 |
| 4 | `src/api/mod.rs` | FRB 导出 `list_agents`、`read_agent_config`、`write_agent_config`、`create_agent`、`delete_agent` |

### Phase 2 — 聊天流程改动

| # | 文件 | 内容 |
|---|------|------|
| 5 | `src/api/mod.rs` | `chat_stream` / `chat` 增加 `config_path` 动态参数（不再是固定路径） |
| 6 | `src/commands/mod.rs` | 透传动态 `config_path` |
| 7 | `src/commands/chat/mod.rs` | `run()` 使用传入的 `config_path` 而非 CLI 参数 |

### Phase 3 — Flutter 前端：智能体管理页面

| # | 文件 | 内容 |
|---|------|------|
| 8 | `lib/features/agents/models/agent_info.dart` | `AgentInfo` 数据模型 |
| 9 | `lib/features/agents/models/agent_config_helper.dart` | `extractImportableConfig()` 辅助函数 |
| 10 | `lib/features/agents/store/agent_store.dart` | `AgentStore` 状态管理 |
| 11 | `lib/features/agents/pages/agent_list_page.dart` | 智能体列表页 |
| 12 | `lib/features/agents/pages/agent_edit_page.dart` | 智能体创建/编辑页（含从全局导入） |
| 13 | `lib/features/agents/widgets/agent_selector.dart` | 聊天页智能体选择器 |

### Phase 4 — 集成

| # | 文件 | 内容 |
|---|------|------|
| 14 | `lib/features/settings/settings_page.dart` | 侧边栏增加"智能体" Tab，新增 `selectedAgent` 状态 |
| 15 | `lib/features/chat/` | 输入框上方嵌入 `AgentSelector` |
| 16 | `lib/store/config_store.dart` | 无改动（智能体配置与全局配置各自独立保存） |
| 17 | `lib/features/skills/store/skill_store.dart` | 无改动（技能扫描结果全局共享） |

---

## 边界情况

| 问题 | 处理方式 |
|------|---------|
| **没有 agents/ 目录** | `list_agents` 只返回"全局智能体"，聊天行为与现在完全一致 |
| **智能体 config.json 解析失败** | 跳过该智能体，`AgentSummary` 的 name 回退为文件夹名，description 为空 |
| **智能体引用了不存在的 MCP 命令** | MCP Manager 连接失败时记录错误事件，不影响聊天 |
| **智能体引用了不存在的技能** | `skills` 中存在的 id 但在全局扫描中找不到 → 静默忽略（system prompt 中不注入） |
| **删除正在使用的智能体** | 自动回退到"全局智能体" |
| **智能体配置中没有 `default_model`** | 聊天时使用 CLI 或 Flutter 传入的 `--provider` / `--model` 参数 |
| **智能体没有 `mcpServers`** | 不初始化任何 MCP 连接 |
| **智能体没有 `skills`** | 不注入任何技能到 system prompt |

---

## 与现有 skill-system.md 的关系

智能体系统是**技能系统的上一层抽象**：

| 层 | 系统 | 配置来源 | 说明 |
|----|------|---------|------|
| 应用 | 全局智能体 | `config.json` | 整个应用的默认行为 |
| 智能体 | 自定义智能体 | `agents/<id>/config.json` | 按场景切换的配置集合 |
| 能力 | 技能系统 | `~/.agents/skills/` 等全局目录 | 技能文件本身（SKILL.md） |
| 能力 | MCP 系统 | `mcpServers` 配置 | 外部工具/资源 |

技能文件本身仍存放在 `~/.agents/skills/` 等全局目录中不变。智能体通过 `config.json` 的 `skills` 字段控制**启用哪些已发现的技能**，而不是管理技能文件本身。
