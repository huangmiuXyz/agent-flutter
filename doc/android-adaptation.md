# Android 移动端适配文档

> 适用范围：`agent-flutter`（Flutter + flutter_rust_bridge 2.12 + Rust 后端）
> 状态：进行中 —— M0「构建 + 启动 + 聊天」已打通（步骤 1/2/3/4/6/8），第 7 步手机 UI 化待实施
> 最后更新：2026-08-23

---

## 1. 概述

### 1.1 目标

把目前**纯桌面**（Windows/macOS）架构的 AI 智能体应用适配到 Android 手机。

### 1.2 里程碑

| 里程碑 | 范围 | 状态 |
|---|---|---|
| **M0** | Android 上能构建、能启动、能聊天（LLM 对话 + HTTP MCP + 应用私有目录文件工具），终端工具明确降级禁用 | 步骤 1/2/3/4/6/8 完成；第 7 步 UI 化待做 |
| **M1** | 终端/命令执行在 Android 的可行方案（打包 busybox 原生二进制 或 命令执行移到远端）；SAF 目录级直读；编辑器完善 | 未开始 |

### 1.3 已确认的决策

- 仅支持 **arm64 真机**（`aarch64-linux-android`）；工具链同时配置了 armv7 / x86 / x86_64 以便 `flutter build apk` 默认多 ABI 构建不失败
- M0 **禁用终端**（AI 执行命令的 PTY 链路），文件类工具 + HTTP MCP 保留
- 手机端工作目录接入 **SAF 目录选择**（导入副本到应用目录，见 §6.6）
- 手机端纳入 **app 内编辑器**（code_forge 全屏路由，LSP 降级）
- 手机端主导航：**底部 2 tab（会话列表 / 设置）+ 点会话进聊天页**（见 §4.2）

---

## 2. 架构现状

### 2.1 技术栈

- Flutter（Dart SDK ^3.12.2），`go_router` 路由、`signals` 响应式状态
- Rust 后端经 **flutter_rust_bridge 2.12** 内嵌（`rust_lib_agent`，位于 `../agent-flutter-cli/`）
- 编辑器插件 `code_forge`（`.patches/code_forge`，自带 cargokit）

### 2.2 桌面专属依赖（Android 不可用的关键点）

| 依赖 | 用途 | Android 表现 |
|---|---|---|
| `window_manager` | 窗口管理、隐藏标题栏 | 运行时抛 `MissingPluginException`，需平台守卫 |
| `desktop_multi_window` | 编辑器子窗口、跨窗口广播 | 同上 |
| `flutter_pty_new` | 交互式 PTY 终端 | 可编译（CMake+NDK），但 Android 无 shell/git 工具链，实际不可用 |
| `desktop_drop` | 拖拽文件进终端 | 注册无害，拖拽不触发 |
| `win32` + `ffi` | Windows 注册表读系统字体 | 仅在 Windows 有效 |
| Rust `tokio::process` | shell / git / MCP stdio 子进程 | Android 沙盒无 `/bin/bash`、`node`、`python`、`git` |

### 2.3 架构结论

- 应用层基于 3 个桌面能力：**原生子窗口**、**原生窗口管理**、**PTY 终端**；M0 均已降级/守卫
- **PTY 终端是核心**（AI 执行命令依赖 `simulated_terminal`/`terminal_send_input` 前端工具），无非 PTY 回退 —— 这是 M0 明确禁用的原因
- **Rust 文件工具基于 `std::fs`**，无法直接读 Android `content://` SAF URI —— 工作目录需桥接（§6.6）

---

## 3. 已完成改造

### 3.1 步骤 1 —— Rust 交叉编译链

- 安装 rustup 目标：`aarch64-linux-android`、`armv7-linux-androideabi`、`i686-linux-android`、`x86_64-linux-android`
- `agent-flutter-cli/.cargo/config.toml`：
  - 4 个 Android target 的 NDK `clang` 链接器（NDK 28.2.13676358，minSdk 24 → 用 `*-android24-clang.cmd`）
  - `-C link-arg=-Wl,-z,max-page-size=16384`（Android 15+ 16KB 页对齐，targetSdk 36 必需）
  - `[env]` 固化 `ANDROID_NDK_HOME/ROOT` 与 `CC_*/AR_*`，cargokit/gradle 构建无需手动设环境变量
- ⚠️ cargo config 的 `${var}` 变量引用会在 `[target.*]` 表内被相对解析导致报错，**必须硬编码完整路径**（不要用 `_n`/`_bt` 这类顶层变量）
- 验证：`cargo build --release --target aarch64-linux-android -p rust_lib_agent` 产出 `librust_lib_agent.so`

### 3.2 步骤 2 —— FRB Android 集成

- 执行 `flutter_rust_bridge_codegen integrate --rust-crate-dir ../agent-flutter-cli --rust-crate-name rust_lib_agent --no-write-lib --no-integration-test`
  - 生成 `rust_builder/` 插件包（cargokit），加入 `pubspec.yaml`（`rust_lib_agent: path: rust_builder`）
  - `rust_builder/android/build.gradle` 的 `manifestDir = ../../../agent-flutter-cli`、`libname = rust_lib_agent` 正确指向 Rust crate
- **Gradle 9 兼容修复**（两处 cargokit 副本：`rust_builder/` 与 `.patches/code_forge/` 的 `cargokit/gradle/plugin.gradle`）：
  - `Project.exec{}` 在 Gradle 9 已移除 → 注入 `ExecOperations`，用 `execOperations.exec{}`
  - `providers.exec{}.get()` 返回的是 `ExecOutput`，需 `.result.get()` —— 最终方案统一用 `execOperations`
- `rust_builder/android/build.gradle`：`compileSdkVersion` 33→36、`minSdkVersion` 19→24
- 环境修复：
  - Android SDK 缺 CMake → 手动从 `dl.google.com/android/repository/cmake-3.22.1-windows.zip` 安装到 `$SDK/cmake/3.22.1`（zip 顶层是 `bin/share/doc`，需完整展开，缺 `share/` 会报 `Could not find CMAKE_ROOT`）
  - `flutter_local_notifications` 需 core library desugaring → `android/app/build.gradle.kts` 加 `isCoreLibraryDesugaringEnabled` + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`
  - Kotlin 增量编译跨盘崩溃（pub 缓存在 C:、项目在 E:）→ `android/gradle.properties` 加 `kotlin.incremental=false`

### 3.3 步骤 3 —— manifest 权限与包名

- `android/app/src/main/AndroidManifest.xml`：
  - 补 `android.permission.INTERNET`（release 构建联网必需，Rust reqwest 全部走网络）
  - 补 `android.permission.POST_NOTIFICATIONS`（Android 13+ 本地通知）
- `android/app/build.gradle.kts`：`namespace` / `applicationId` → `com.agentqi.agent`
- `MainActivity.kt` 移至 `com/agentqi/agent/` 并更新包声明

### 3.4 步骤 4 —— 运行时平台适配

- 新增 `lib/utils/platform.dart`：`isDesktopPlatform` / `isMobilePlatform`（基于 `defaultTargetPlatform` + `kIsWeb`，测试可注入）
- `lib/main.dart`：
  - 子窗口检测收进 `if (isDesktopPlatform)`
  - 全部 `windowManager` 调用（`ensureInitialized`/`setPreventClose`/`WindowOptions`/`waitUntilReadyToShow`）收进桌面分支
  - 移动端直接 `initAppSync()` + `runApp(AgentApp())`
- `lib/app.dart`：`VirtualWindowFrameInit()` 仅桌面包一层，移动端透传 child（该组件在非桌面平台本就透传，守卫仅为明确意图）
- `lib/layout/main_layout.dart`：新增移动端分支（简单顶栏 + `resizeToAvoidBottomInset: true` 适配软键盘）
- `lib/utils/file_utils.dart`：`openFile` 移动端只更新 `CodeForgeStore`，跳过子窗口创建
- `lib/features/editor/editor_window.dart`：`windowManager.setTitle` 加桌面守卫

### 3.5 步骤 6 —— 路径模型（path_provider）

- `lib/utils/platform_dirs.dart`：新增 `initAppDataDir()`（移动端用 `path_provider.getApplicationSupportDirectory()` 缓存；桌面端 no-op 保持环境变量逻辑）；`appDataDir()` 优先移动端缓存目录
- `lib/main.dart`：`frb.RustLib.init()` 之前调用 `await initAppDataDir()`，保证任何 store 访问前路径就绪
- 一处改造覆盖 4 个持久化点，且 Rust 经 FRB 参数自动一致：
  - `config.json`、SQLite `data`、`setting.json`、`current_editor_file`
- 首次运行由 `JsonFileSignalStore.writeToDisk()` 自动用 `defaults()` 生成 `config.json`
- Rust `agent_config::read_config_json` 直接用传入路径，无相对路径回退，单点修复全局生效

### 3.6 步骤 8 —— 工具降级

**Rust 侧（编译期平台门控 `cfg(not(target_os = "android"))`）**

| 文件 | 改动 |
|---|---|
| `crates/core/src/builtin_tools.rs` | `register_all` 与 `list_options` 排除 `ShellTool`（`shell_command`）；import 拆分加 cfg |
| `crates/cli/src/commands/mod.rs` `build_tools` | Android 跳过 `set_enabled_tools`（builtinTools 白名单过滤），注册表全启用 → **MCP 工具开箱即用**；桌面行为不变 |
| `crates/core/src/sub_agent.rs` `build_sub_agent_registry` | 同样跳过 builtinTools 过滤，`finish_sub_agent` 照常注册 |

**Dart 侧**

- `lib/services/engine/frontend_tools.dart`：`registerFrontendTools()` 移动端直接返回，不注册 `simulated_terminal`/`terminal_send_input`

**Android 最终工具集**

| 工具 | Android |
|---|---|
| load_skill / apply_patch / read_file / grep / find_path / list_directory / spawn_sub_agent | ✅ 可用 |
| MCP 工具（HTTP 传输） | ✅ 可用（免 builtinTools 勾选） |
| shell_command / simulated_terminal / terminal_send_input | ❌ 不存在于注册表 |

- git checkpoint：Android 上 `resolve_gitdir` 因非 git 仓库返回 `None` 自动跳过，不阻塞编辑工具

---

## 4. 手机 UI 化计划（第 7 步，待实施）

### 4.1 设计原则

- 只改表现层：业务逻辑、signals 状态、Rust 引擎不动；改动以 `isMobilePlatform` / MediaQuery 守卫，**桌面布局零影响**
- 复用现有组件内容（LeftPanel / SettingsPage 等），只改容器与交互入口
- 不引入新状态管理；用最小响应式工具替代写死的桌面尺寸

### 4.2 信息架构（已确认）

```
底部壳 (MainShell)
├── Tab 1  会话列表（含 会话/检查点 切换，沿用桌面 LeftPanel 内容）
└── Tab 2  设置（全屏 tab，不再用模态弹窗）
全屏页（覆盖壳，带返回）
├── /chat/:sessionId   聊天页（消息 + 输入，无左栏/终端/右栏）
└── /editor            应用内编辑器（code_forge）
```

### 4.3 实施阶段

**Phase A — 响应式基础**
- A1 `utils/layout_utils.dart`：`readingWidth`（写死主屏半宽，`:5-8`）→ 函数 `readingWidthFor(context)` = `min(屏宽−边距, 720)`；替换 5 处调用（chat_input:31、chat_content:105、message_list:865/878、content_frame:33），桌面宽度用 `isCompactWidth` 守卫不变。**这是最严重的移动端 bug：360dp 屏下聊天内容会被压到 180dp**
- A2 新增 `utils/responsive.dart`：`isCompactWidth`（<600dp）断点
- A3 新增 `layout/main_shell.dart`：`StatefulShellRoute.indexedStack` 两分支 + 底部导航

**Phase B — 路由与导航重构（架构核心）**
- B1 `router.dart` 平台分支：桌面保持现状；手机 `StatefulShellRoute`（会话/设置）+ 壳外全屏 `/chat/:id`、`/editor`
- B2 会话列表页：复用 LeftPanel 内容抽成独立页面，去侧栏宽度 / hover 批量选择依赖
- B3 点会话 → `context.go('/chat/:id')` + `SessionStore.switchTo(id)`；聊天页 AppBar：返回 + 标题 + 命令面板按钮
- B4 `showSettingsDialog`（main_layout.dart:29-69）手机端改为切设置 tab 并透传 `settingsPanelTarget`；桌面维持模态
- B5 设置 tab 内嵌 `SettingsPage`

**Phase C — ChatPage 手机单栏**
- C1 `chat_page.dart` 移动分支仅渲染 `ChatContent`（消息+输入）
- C2 终端面板移动端不渲染；`XtermStore.expandRequest` 移动端忽略；**工具输出卡片 `ReadonlyTerminalView` 保留**（纯 xterm 渲染，不依赖 PTY，Android 可用）
- C3 软键盘收缩验证

**Phase D — 聊天输入与消息交互**
- D1 `chat_input.dart:136-186` 工具栏两行化 + 「更多」底部弹层收纳 work_dir/agent/model 选择器，发送/停止保持可见
- D2 `chat_fleather.dart:354-373`：手机 `textInputAction: TextInputAction.send` + `onSubmitted` 发送；换行入口放「更多」菜单；复用 `ImeComposingTracker`
- D3 hover-only 动作触摸化（长按操作条 / 始终可见）：session_list 删除、left_panel:169 批量选择、work_dir_selector:302 历史删除、checkpoint_path_list:96 删除
- D4 图片选择验证：file_picker Android 返回缓存绝对路径，`ImageStore.importImage`（File.copy）基本可用；个别机型 `path==null` 补 content-URI 分支

**Phase E — 设置与工作目录（SAF）**
- E1 `settings_page.dart:248` 两栏 → 手机顶部横向 TabBar 单栏
- E2 `app_form_page.dart kFormPageWidth=560` → `min(560, 屏宽−32)`
- E3 SAF 工作目录：work_dir 默认应用文档目录（Rust 可 FS 读写）；SAF 目录选择（`file_picker.getDirectoryPath`）→ **导入副本到应用工作目录**；`takePersistableUriPermission` 需真机验证（可能需 MainActivity MethodChannel）
- E4 `AppFilePathField` 手机端替换为 SAF 选择器 + 显示当前应用工作目录

**Phase F — app 内编辑器**
- F1 `/editor` 全屏路由；`openFile` 手机端 `go('/editor')`（子窗口逻辑已在步骤 4 降级）
- F2 `EditorWindow` 复用为全屏页（返回键，`windowManager` 已守卫）
- F3 `tryStartLsp` 手机端跳过（LSP 是外部桌面二进制）
- F4 文件访问基于应用工作目录

**Phase G — 命令面板**
- G1 `command_palette.dart` 宽度 `min(屏宽,560)`；触摸点击条目执行
- G2 入口：聊天页 AppBar + 会话列表页顶部

**Phase H — 收尾验证**
- H1 `flutter analyze` + `flutter build apk --debug --target-platform android-arm64`
- H2 真机走查清单（§8）
- H3 桌面回归 `flutter run -d windows`

---

## 5. 构建指南

### 5.1 环境要求

| 项 | 要求 |
|---|---|
| Rust | 已装 rustup 目标：`aarch64-linux-android` 等 4 个 |
| Android SDK | NDK `28.2.13676358`；CMake `3.22.1`（`$SDK/cmake/3.22.1/bin/cmake.exe`，含 `share/`） |
| Flutter | `flutter.minSdkVersion` = 24，compileSdk/targetSdk 36 |
| 网络 | cargo 走 rsproxy.cn；gradle/androidx 走 google maven |

### 5.2 构建命令

```powershell
# 1. Rust 交叉编译（可直接用，[env] 已固化）
cargo build --release --target aarch64-linux-android -p rust_lib_agent   # 在 agent-flutter-cli 下

# 2. 打 APK（仅 arm64）
flutter build apk --debug --target-platform android-arm64

# 3. 打 APK（默认多 ABI：arm64/armv7/x86/x86_64）
flutter build apk --debug

# 4. 装到真机
flutter install --debug
```

产物：`build/app/outputs/flutter-apk/app-debug.apk`，含 `lib/arm64-v8a/librust_lib_agent.so`。

### 5.3 桌面开发（回归验证）

```powershell
# Windows（需要 MSVC 环境，走项目脚本）
cmd.exe /c "tools\run_in_msvc_env.bat flutter run -d windows"
```

---

## 6. 平台降级策略

### 6.1 终端 / PTY
- 交互终端面板：手机端不渲染；`flutter_pty_new` 可编译但 Android 无 shell 工具链，实际不可用
- 工具输出渲染：`ReadonlyTerminalView` 为纯 xterm 渲染，**Android 保留**

### 6.2 工具集
- 编译期 `cfg(not(target_os = "android"))` 排除 `ShellTool`；Dart 端移动端不注册终端前端工具
- Android 跳过 builtinTools 白名单过滤（注册表全启用），MCP 工具开箱即用

### 6.3 MCP
- **HTTP 传输可用**（纯网络客户端，`manager.rs:454`）
- **STDIO 传输不可用**（`Command::new` 拉本地子进程，Android 无 node/python/shell）
- Android 配置只放 HTTP 类型服务器

### 6.4 编辑器（code_forge）
- 手机端改为 app 内全屏路由；`tryStartLsp` 跳过（LSP 为外部桌面二进制）
- `code_forge` 自带 cargokit，已在 APK 中打包 `libcode_forge.so`

### 6.5 检查点
- 基于 git refs，Android 非 git 仓库时 `resolve_gitdir` 返回 `None` 自动跳过；UI 保留空态

### 6.6 工作目录 / SAF（关键约束）
- **Rust 文件工具基于 `std::fs`，无法读 `content://` URI** —— 这是手机端工作目录的最大架构约束
- M0 方案：
  - `work_dir` 默认 = `getApplicationDocumentsDirectory()`（应用私有，Rust 可直接读写）
  - SAF 目录选择 → 导入所选目录内容**副本**到应用工作目录（增量），供 read_file/apply_patch/grep 操作
  - SAF 选**单个文件**场景：content-URI 读取 + 缓存到工作目录
- 目录级 SAF 直读（在 URI 上直接 grep/list_directory）属 M1

---

## 7. 风险与限制

| # | 风险 | 说明 / 对策 |
|---|---|---|
| 1 | Rust 文件工具 vs SAF URI | `std::fs` 不可读 `content://`；M0 用「导入副本」桥接，目录级直读留 M1 |
| 2 | SAF 持久化权限 | `takePersistableUriPermission` 需真机验证，可能需在 `MainActivity.kt` 加 MethodChannel 或换插件 |
| 3 | Fleather 手机键盘语义 | Enter=发送 / 换行需真机验证 `textInputAction` 行为 |
| 4 | `readingWidth` 改函数式 | 必须保证桌面阅读宽度不变（`isCompactWidth` 守卫） |
| 5 | 路由重构影响面 | 平台分支隔离，桌面分支零改动 |
| 6 | 通知 | `SystemNotificationService` 只配了 macOS/windows channel，Android 通知后续补 channel + `POST_NOTIFICATIONS` 运行时请求 |
| 7 | 字体服务 | `SystemFontService`（win32 注册表 / fc-list）在 Android 为空，导入字体走 FilePicker 即可 |
| 8 | Windows 开发流 | `windows/flutter/generated_plugins.cmake` 重生成后 rust_builder 会随 `flutter build windows` 自动编译；原 Makefile 手工 build+copy dll 流程可能冗余，需确认 |

---

## 8. 验证清单（真机）

### 8.1 M0 已验收项
- [x] `cargo build --release --target aarch64-linux-android -p rust_lib_agent` 出 `.so`
- [x] `flutter build apk --debug --target-platform android-arm64` 成功，APK 含 `lib/arm64-v8a/librust_lib_agent.so`
- [x] `flutter analyze` 零问题
- [x] Rust 桌面 Windows `cargo check` 通过（`cfg(not(android))` 路径未破坏）

### 8.2 第 7 步完成后真机走查
- [ ] 启动不崩（无 MissingPluginException），进入会话列表
- [ ] 新建/切换/删除会话
- [ ] 配置 provider（设置 tab）→ 发消息 → 流式回复
- [ ] 发图片
- [ ] 会话列表 → 点击进聊天页 → 返回
- [ ] 命令面板（AppBar 入口）打开/执行
- [ ] SAF 选择工作目录 → agent 在应用工作目录内 read_file/apply_patch
- [ ] 打开文件进 app 内编辑器 → 编辑保存
- [ ] 软键盘不遮挡输入框
- [ ] 桌面回归：`flutter run -d windows` 布局/快捷键/多窗口无回归

---

## 9. 相关文件速查

| 用途 | 路径 |
|---|---|
| 平台判断 | `lib/utils/platform.dart` |
| 应用数据目录 | `lib/utils/platform_dirs.dart` |
| 平台适配启动 | `lib/main.dart` |
| 移动端外壳 | `lib/layout/main_layout.dart`（移动分支）、`lib/layout/main_shell.dart`（待建） |
| 工具降级 | `lib/services/engine/frontend_tools.dart` |
| 路由 | `lib/router/router.dart` |
| Rust 工具注册 | `agent-flutter-cli/crates/core/src/builtin_tools.rs`、`crates/cli/src/commands/mod.rs`、`crates/core/src/sub_agent.rs` |
| 构建配置 | `agent-flutter-cli/.cargo/config.toml`、`android/app/build.gradle.kts`、`android/app/src/main/AndroidManifest.xml` |
| FRB 集成 | `rust_builder/`（生成代码，.gitignore）、两处 `cargokit/gradle/plugin.gradle` |