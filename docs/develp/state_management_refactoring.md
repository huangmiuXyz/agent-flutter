# 状态管理重构方案：全面迁移至 Pinia 风格

> 本文档记录了 Agent 项目状态管理从 Riverpod + Signals 混用模式，全面统一至 Signals Pinia 风格的过程和规范。

---

## 一、前言

### 1.1 为什么要重构

项目目前存在三套状态管理模式混用的问题：

| 模式 | 使用范围 | 问题 |
|---|---|---|
| `@riverpod` 注解式 | `config_service.dart`、`llm_providers.dart`、`theme/provider.dart`、`xterm_provider.dart`、`layout_utils.dart` | 注解+代码生成，逻辑不透明；三种写法（class/function/notifier）规则不一致 |
| Signals + 全局单例 | `SessionManager` | 风格正确，但孤立在 `services/session/` 下，与主体不一致 |
| `flutter_hooks` 局部状态 | 各 widget 的 `useState`、`useMemoized` | 局部状态方案不动，全局状态应与此解耦 |

**核心痛点：**
- `@riverpod` 注解生成的 provider 命名全靠"约定"（`ThemeNotifier` → `themeProvider`，而不是 `themeNotifierProvider`），新人无法直接推断
- 同一个文件（如 `config_service.dart`）混用三种 `@riverpod` 写法
- `SessionManager` 是全局单例却走 signals，其他状态走 Riverpod，**同一个组件里同时用 `ref.watch` 和 `SignalBuilder`**
- `SelectedSession`（Riverpod）和 `SessionManager.instance.selectedId`（Signals）功能重复
- Code generation（`build_runner`）增加了构建环节和排错成本

### 1.2 目标

将所有全局状态收归 `lib/store/` 目录，统一采用 **Pinia 风格**：

```
lib/store/
├── app_store.dart          # 汇聚导出
├── session_store.dart      # 会话状态
├── theme_store.dart        # 主题状态
├── config_store.dart       # 配置状态
├── llm_store.dart          # LLM 状态
├── xterm_store.dart        # 终端状态
└── layout_store.dart       # 布局状态
```

**什么是 Pinia 风格？**

Pinia（Vue 官方状态管理）的核心模式是 **Composition API Store**，翻译成 Dart：

```dart
// ── 一个 store = 一个普通 Dart 类 ──
class ThemeStore {
  // 单例
  static final instance = ThemeStore._();
  ThemeStore._();

  // ① state → signal()
  final themeMode = signal(ThemeMode.system);
  final fontWeight = signal(400);

  // ② getters → computed()
  late final effectiveBrightness = computed(() { ... });

  // ③ actions → 普通方法
  void toggle() { themeMode.value = ...; }
  void setThemeMode(ThemeMode m) { themeMode.value = m; }
}

// 使用：直接 import + 读 .value
themeStore.themeMode.value          // 读
themeStore.themeMode.value = mode   // 写
themeStore.toggle()                 // 调用 action

**关键特征：**
- ❌ 无注解、无代码生成、无 DI 容器
- ❌ 无 `ref.watch` / `ref.read` / `ConsumerWidget`
- ✅ 纯 Dart 类 + `signal()` / `computed()`
- ✅ UI 层通过 `HookWidget` + `useExistingSignal()` 绑定
- ✅ 全局单例，直接 import，直接读写

### 1.3 不变的部分

以下内容**不在此次重构范围内**：

- **`flutter_hooks` 局部状态** — `useState`、`useMemoized`、`useEffect` 等继续在组件内部使用
- **纯工具类** — `ConfigFileStore`（JSON 读写）、`LlmService`（Rust bridge 调用）、`CommandRunner` 等继续留在 `services/`
- **Widget / 组件库** — 视觉组件不改动
- **路由 / 页面结构** — 不变

---

## 二、迁移步骤

整体策略：**逐个替换，每步可编译**。

每完成一步，项目必须能正常编译通过。不积攒未使用的 store，也不积攒未清理的旧代码。

```
迁移节奏：
  写 ThemeStore  →  改所有用 themeProvider 的 UI  →  删 theme/provider.dart
  写 ConfigStore  →  改所有用 config 相关 provider 的 UI  →  清 config_service.dart
  写 LlmStore    →  改所有用 llm 相关 provider 的 UI  →  删 llm_providers.dart
  搬 SessionStore → 改所有 SessionManager 引用       →  删 session_manager.dart
  写 XtermStore   →  改所有用 xterm 相关 provider 的 UI → 删 xterm_provider.dart
  写 LayoutStore →  改所有用 layout 相关 provider 的 UI → 删 layout_utils.dart
  收尾扫荡       →  清依赖、删残余
```

### 入口修改（贯穿全程）

`main.dart` 和 `app.dart` 中的 `ProviderScope` 需要在所有 `ref` 用完之后才能移除。
建议在最后一步再处理，前期保留不影响。

---

### Step 1：ThemeStore — 写 store + 改 UI + 删旧文件

这是最简单的切入点（主题不依赖其他 store，依赖方清晰）。

**① 写 `lib/store/theme_store.dart`**

替换 `theme/provider.dart` 中的 `ThemeNotifier`、`effectiveBrightness`、`PlatformBrightness`：

```dart
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:signals/signals.dart';

import 'package:agent/theme/app_theme.dart';
import 'package:agent/theme/custom_theme.dart';

class ThemeStore {
  static final instance = ThemeStore._();
  ThemeStore._();

  final themeMode = signal(ThemeMode.system);
  final fontWeight = signal(400);
  final lightOverrides = signal(<AppColorRole, int>{});
  final darkOverrides = signal(<AppColorRole, int>{});

  late final effectiveBrightness = computed(() {
    return switch (themeMode.value) {
      ThemeMode.system => _platformBrightness(),
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
    };
  });

  void toggle() {
    themeMode.value = effectiveBrightness.value == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  void setThemeMode(ThemeMode mode) => themeMode.value = mode;
  void setFontWeight(FontWeight w) => fontWeight.value = w.value;

  void setColor(Brightness brightness, AppColorRole role, Color color) {
    final overrides = Map<AppColorRole, int>.of(
      brightness == Brightness.dark ? darkOverrides.value : lightOverrides.value,
    )..[role] = color.toARGB32();

    if (brightness == Brightness.dark) {
      darkOverrides.value = Map.unmodifiable(overrides);
    } else {
      lightOverrides.value = Map.unmodifiable(overrides);
    }
  }

  void resetColors({Brightness? brightness}) { /* ... */ }
  void resetAll() {
    themeMode.value = ThemeMode.system;
    fontWeight.value = 400;
    lightOverrides.value = {};
    darkOverrides.value = {};
  }

  static Brightness _platformBrightness() =>
      PlatformDispatcher.instance.platformBrightness;
}
```

**② 改 UI：** 将所有 `ConsumerWidget` / `HookConsumerWidget` 改为 `HookWidget`，`ref.watch(xxx)` 改为 `useExistingSignal(xxxStore.xxx)`。

```dart
// Before
class MyWidget extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    return Text('${theme.themeMode}');
  }
}

// After
class MyWidget extends HookWidget {
  Widget build(BuildContext context) {
    final theme = useExistingSignal(themeStore.themeMode);
    return Text('${theme.value}');
  }
}
```

涉及文件：
| 文件 | 改动 |
|---|---|
| `lib/app.dart` | `ConsumerWidget` → `HookWidget`，`ref.watch(themeProvider)` → `useExistingSignal(themeStore.themeMode)` |
| `lib/features/settings/pages/*.dart` | 同上 |
| `lib/dev/color_theme_editor.dart` | `ref.watch(themeProvider)` → `useExistingSignal`，`.notifier` 调用 → 直接调 store 方法 |
| `lib/dev/demo_page.dart` | 同上 |
| `lib/widgets/terminal/terminal_palette.dart` | `@riverpod xtermTheme` 改为从 `themeStore` 读取 |

**③ 删旧文件：** `lib/theme/provider.dart`、`lib/theme/provider.g.dart`、`lib/theme/theme_settings.dart`（如果无其他地方引用）

**④ 验证：** `flutter analyze` 无错误

---

### Step 2：ConfigStore — 写 store + 改 UI + 清旧代码

**① 写 `lib/store/config_store.dart`**

替换 `config_service.dart` 中的 `@riverpod class ConfigPath`、`DbPath`、`DefaultModel`、`@riverpod function configFileStore`。

`ConfigFileStore`（JSON 文件读写工具类）保留在 `services/config_service.dart`，不搬。

```dart
import 'dart:convert';
import 'dart:io';
import 'package:signals/signals.dart';
import 'package:agent/services/config_service.dart';  // ConfigFileStore
import 'package:agent/utils/platform_dirs.dart';

class ConfigStore {
  static final instance = ConfigStore._();
  ConfigStore._();

  final configPath = signal('');
  final dbPath = signal('');
  final defaultModel = signal<Map<String, String>?>(null);

  void init() {
    configPath.value = _resolveConfigPath();
    dbPath.value = _resolveDbPath();
    defaultModel.value = _readDefaultModel();
  }

  void setDefaultProvider(String provider, String model) {
    defaultModel.value = {'provider': provider, 'model': model};
    ConfigFileStore(configPath.value)
        .writePath('default_model', {'provider': provider, 'model': model});
  }

  bool _inProjectDir() {
    return File('./config.json').existsSync() ||
        File('./pubspec.yaml').existsSync() ||
        Directory('./data').existsSync();
  }

  String _resolveConfigPath() {
    const compileEnv = String.fromEnvironment('CONFIG_PATH');
    if (compileEnv.isNotEmpty) return compileEnv;
    final runtimeEnv = Platform.environment['AGENT_CONFIG_PATH'];
    if (runtimeEnv != null && runtimeEnv.isNotEmpty) return runtimeEnv;
    if (_inProjectDir()) return '../agent-flutter-cli/config.json';
    return appDataDir(['agent', 'config.json']);
  }

  String _resolveDbPath() {
    const compileEnv = String.fromEnvironment('DB_PATH');
    if (compileEnv.isNotEmpty) return compileEnv;
    final runtimeEnv = Platform.environment['AGENT_DB_PATH'];
    if (runtimeEnv != null && runtimeEnv.isNotEmpty) return runtimeEnv;
    if (_inProjectDir()) return '../agent-flutter-cli/data/data';
    return appDataDir(['agent', 'data', 'data']);
  }

  Map<String, String>? _readDefaultModel() {
    final raw = ConfigFileStore(configPath.value).readPath('default_model');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final provider = decoded['provider'] as String?;
      final model = decoded['model'] as String?;
      if (provider != null && model != null) return {'provider': provider, 'model': model};
    } catch (_) {}
    return null;
  }
}
```

**② 改 UI：** 所有 `ref.watch(configPathProvider)` / `ref.watch(dbPathProvider)` / `ref.watch(defaultModelProvider)` 改为 `configStore.configPath.value` 等。

涉及文件：
- `lib/features/chat/chat_input.dart` — `ref.read(dbPathProvider)` → `configStore.dbPath.value`
- `lib/features/chat/panels/session_list.dart` — `ref.read(dbPathProvider)` → `configStore.dbPath.value`
- `lib/features/settings/pages/*.dart` — `ref.read(configPathProvider)` 等
- `lib/services/llm/llm_providers.dart`（将在下一步删除）— 临时改为 `configStore` 引用

**③ 清旧代码：** 从 `config_service.dart` 中删除 `@riverpod class ConfigPath`、`DbPath`、`DefaultModel`、`@riverpod function configFileStore`，以及对应的 `part 'config_service.g.dart'`。保留 `ConfigFileStore` 工具类。

**④ 验证：** `flutter analyze` 无错误

---

### Step 3：LlmStore — 写 store + 改 UI + 删旧文件

**① 写 `lib/store/llm_store.dart`**

替换 `llm_providers.dart` 全部 7 个 @riverpod。

```dart
import 'package:signals/signals.dart';
import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/services/llm/llm_service.dart';

class LlmStore {
  static final instance = LlmStore._();
  LlmStore._();

  final service = LlmService();
  final initialized = signal(false);

  final currentProvider = signal('');
  final currentModel = signal('');

  final providers = signal(<api.ProviderSummary>[]);
  final providersLoading = signal(true);
  final models = signal(<String>[]);
  final modelsLoading = signal(true);

  Future<void> init() async {
    await service.init();
    initialized.value = true;
  }

  Future<void> loadProviders(String configPath) async {
    providersLoading.value = true;
    try {
      providers.value = await service.listProviders(configPath: configPath);
    } finally {
      providersLoading.value = false;
    }
  }

  Future<void> loadModels(String configPath) async {
    if (currentProvider.value.isEmpty) return;
    modelsLoading.value = true;
    try {
      models.value = await service.listModels(
        provider: currentProvider.value,
        configPath: configPath,
      );
    } finally {
      modelsLoading.value = false;
    }
  }

  void selectProvider(String p) => currentProvider.value = p;
  void selectModel(String m) => currentModel.value = m;
}
```

**② 改 UI：**

| 旧写法 | 新写法 |
|---|---|
| `ref.watch(llmInitProvider.future)` | 改用 `llmStore.initialized.value` + 自行 await |
| `ref.watch(currentProviderProvider)` | `llmStore.currentProvider.value` |
| `ref.watch(currentModelProvider)` | `llmStore.currentModel.value` |
| `ref.watch(providersListProvider)` | `llmStore.providers.value`，`providersLoading` 控制加载态 |
| `ref.watch(modelsListProvider)` | `llmStore.models.value`，`modelsLoading` 控制加载态 |
| `ref.read(llmServiceProvider)` | `llmStore.service` |
| `saveDefaultProvider(ref, ...)` / `saveDefaultModel(ref, ...)` | `configStore.setDefaultProvider(...)` |

**③ 删旧文件：** `lib/services/llm/llm_providers.dart` + `.g.dart`

**④ 验证：** `flutter analyze` 无错误

---

### Step 4：SessionStore — 搬 + 改引用 + 删旧文件

**① 写 `lib/store/session_store.dart`**

SessionManager **已经是用 signals 写的 Pinia 风格**，几乎不需要改代码逻辑。

操作：复制 `services/session/session_manager.dart` → `lib/store/session_store.dart`
改动：
- 类名 `SessionManager` → `SessionStore`
- 更新 import 路径

```dart
import 'dart:async';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/services/llm/llm_service.dart';
import 'package:agent/services/session/session_state.dart';
import 'package:agent/services/session/stream_event_processor.dart';

class SessionStore {
  static final instance = SessionStore._();
  SessionStore._();

  // ── 响应式状态 ──
  final sessions = signal(<String, SessionState>{});
  final selectedId = signal<String?>(null);
  final displayedSessionId = signal<String?>(null);
  final sessionList = signal(<api.SessionInfo>[]);
  final sessionListLoading = signal(true);
  final streamingSessionIds = signal(<String>{});

  // ── 以下代码与现有 SessionManager 完全一致 ──
  Future<void> loadSessions(...) async { ... }
  Future<void> switchTo(...) async { ... }
  Future<void> sendMessage(...) async { ... }
  Future<void> retryMessage(...) async { ... }
  Future<void> cancelStreaming(...) async { ... }
  // ...
}
```

**② 改 UI：** 全局搜索 `SessionManager.instance` → 改为 `SessionStore.instance`，或直接改类名后全局替换。

**③ 删旧文件：** `lib/services/session/session_manager.dart`

**④ 验证：** `flutter analyze` 无错误

---

### Step 5：XtermStore — 写 store + 改 UI + 删旧文件

**① 写 `lib/store/xterm_store.dart`**

替换 `widgets/terminal/xterm_provider.dart`。

关键点：Riverpod 的 `.family(id)` → 用 Map + `forId()` 实现：

```dart
import 'package:signals/signals.dart';
import 'package:xterm2/xterm.dart';
import 'package:agent/widgets/terminal/command_runner.dart';
import 'package:agent/widgets/terminal/key_handler.dart';
import 'package:agent/widgets/terminal/pty_manager.dart';

/// 单个终端会话管理器
class XtermSessionManager {
  final String id;
  final Terminal terminal;
  final TerminalController controller;
  final CommandRunner commandRunner;
  PtyManager? _ptyManager;

  XtermSessionManager(this.id)
      : terminal = Terminal(maxLines: 5000),
        controller = TerminalController(),
        commandRunner = CommandRunner();

  void startPty({String shell = '', List<String> args = const []}) {
    _ptyManager = PtyManager(
      id: id,
      terminal: terminal,
      onOutput: commandRunner.feedOutput,
    )..start(shell: shell, args: args);
  }

  void sendInput(String text) => _ptyManager?.sendInput(text);
  void handleTap(CellOffset offset) { /* ... */ }
  Future<String> execute(String cmd, {Duration timeout = const Duration(seconds: 30)}) {
    return commandRunner.execute(cmd, sendInput: sendInput, timeout: timeout);
  }
  void dispose() {
    commandRunner.dispose();
    _ptyManager?.dispose();
  }
  // ... 剪贴板、选择等方法
}

/// 终端 Store — 管理所有终端实例
class XtermStore {
  static final instance = XtermStore._();
  XtermStore._();

  final _terminals = <String, XtermSessionManager>{};
  final activeIds = signal(<String>{});

  XtermSessionManager forId(String id) {
    return _terminals.putIfAbsent(id, () => XtermSessionManager(id));
  }

  void dispose(String id) {
    _terminals.remove(id)?.dispose();
    activeIds.value = _terminals.keys.toSet();
  }

  void disposeAll() {
    for (final t in _terminals.values) t.dispose();
    _terminals.clear();
    activeIds.value = {};
  }
}
```

**② 改 UI：**

| 旧写法 | 新写法 |
|---|---|
| `ref.watch(xtermManagerProvider(id))` | `xtermStore.forId(id)` |
| `ref.watch(xtermRegistryProvider)` | `xtermStore.activeIds.value` |
| `ref.read(xtermManagerProvider(id).notifier).sendInput(...)` | `xtermStore.forId(id).sendInput(...)` |

涉及文件：
- `lib/dev/execute_panel.dart` — `ref.read(xtermRegistryProvider)` → `xtermStore`
- 其他用到 xterm provider 的地方

**③ 删旧文件：** `lib/widgets/terminal/xterm_provider.dart` + `.g.dart`

**④ 验证：** `flutter analyze` 无错误

---

### Step 6：LayoutStore — 写 store + 改 UI + 删旧文件

**① 写 `lib/store/layout_store.dart`**

替换 `utils/layout_utils.dart`：

```dart
import 'dart:ui' show PlatformDispatcher;
import 'package:signals/signals.dart';

class LayoutStore {
  static final instance = LayoutStore._();
  LayoutStore._();

  final readingWidth = signal(0.0);

  void init() {
    final display = PlatformDispatcher.instance.displays.first;
    readingWidth.value = display.visibleSize.width / 2;
  }
}
```

**② 改 UI：** `ref.watch(readingWidthProvider)` → `layoutStore.readingWidth.value`

涉及文件：
- `lib/features/chat/chat_input.dart`
- 其他用到 `readingWidthProvider` 的地方

**③ 删旧文件：** `lib/utils/layout_utils.dart` + `.g.dart`

**④ 验证：** `flutter analyze` 无错误

---

### Step 7：收尾扫荡

**① 写 `lib/store/app_store.dart`（汇聚导出）**

```dart
/// app_store.dart — 汇聚所有 store，方便统一导入

export 'theme_store.dart';
export 'config_store.dart';
export 'llm_store.dart';
export 'session_store.dart';
export 'xterm_store.dart';
export 'layout_store.dart';
```

**② 清理 `main.dart` 中的残余**

如果所有地方都已替换完毕：
- 移除 `main.dart` 中的 `ProviderScope`
- 移除 `import 'package:hooks_riverpod/hooks_riverpod.dart'`
- 移除导入的 `app.dart` 中的 Riverpod 相关代码

**③ 清理 pubspec.yaml 依赖**

```yaml
# 删除（全量替换完毕后）
  flutter_riverpod: ^3.3.2
  hooks_riverpod: ^3.3.2
  riverpod: ^3.3.2
  riverpod_annotation: ^4.0.3

# dev_dependencies 删除
  riverpod_generator: ^4.0.4
  riverpod_lint: ^3.1.4
  build_runner: ^2.15.0

# 如需在 HookWidget 中使用 useExistingSignal
  signals_hooks: ^7.1.0
```

**④ 全局验证**

- `flutter pub get` 成功
- `flutter analyze` 零错误
- `flutter run` 正常运行
- 回归测试清单：
  - [ ] 主题切换（亮/暗/跟随系统）
  - [ ] 会话选择与切换
  - [ ] 发送消息与流式输出
  - [ ] 模型选择器
  - [ ] 终端启动与交互
  - [ ] 设置页面全部功能
  - [ ] 主题颜色自定义

---

## 三、开发注意事项

### 3.1 通用规范

1. **每个 store 一个文件**，文件名 `xxx_store.dart`，类名 `XxxStore`
2. **全部使用单例模式**：`static final instance = XxxStore._(); XxxStore._();`
3. **不允许在 store 中直接 import UI 组件**（如 `widgets/`、`features/`），store 只依赖纯 Dart / signals / services
4. **store 方法命名规则**：
   - 读状态（getter-like）：直接暴露 `signal` 字段，外部读 `.value`
   - 派生状态：`computed()` 或 `late final` getter
   - 写操作：动词开头（`set`、`load`、`toggle`、`reset`、`select`）
5. **store 的 init() 方法**：如果 store 需要异步初始化（如加载配置、初始化 LLM），提供 `init()` 方法，在 `main.dart` 或 `App` 构建时调用

### 3.2 UI 绑定方案：全量使用 `HookWidget` + `useExistingSignal`

所有组件统一使用 `HookWidget`，不引入 `SignalWidget` 或 `SignalBuilder`。

```dart
// ✅ 所有组件统一
class AnyWidget extends HookWidget {
  Widget build(BuildContext context) {
    // store 信号 → useExistingSignal 绑定，自动追踪
    final theme = useExistingSignal(themeStore.themeMode);

    // 局部状态 → 继续用 flutter_hooks
    final editing = useState(false);
    final scrollController = useScrollController();

    return Text('${theme.value} ${editing.value}');
  }
}
```

**规则：**
- 读取 store 中的信号 → `useExistingSignal(store.signal)` → 返回一个 `Signal`，`.value` 取值，自动追踪变化
- 调用 store 的 action → `store.method()`，无需包装
- 局部状态 → 继续用 `useState`、`useMemoized`、`useEffect` 等
- 不需要 `SignalWidget`、`SignalBuilder`、`SignalAnimatedBuilder` 等额外 API

### 3.3 异步状态的约定

对于需要异步加载的数据（如 providers 列表、models 列表），**不要使用 `FutureSignal`**，而是采用 **状态枚举 + loading signal** 的模式，保持与 Pinia 风格一致：

```dart
// ✅ 推荐的 Pinia 风格
final providers = signal(<api.ProviderSummary>[]);
final providersLoading = signal(true);
final providersError = signal<String?>(null);

Future<void> loadProviders(String configPath) async {
  providersLoading.value = true;
  providersError.value = null;
  try {
    providers.value = await service.listProviders(configPath: configPath);
  } catch (e) {
    providersError.value = e.toString();
  } finally {
    providersLoading.value = false;
  }
}
```

不推荐 `FutureSignal`，因为：
- Pinia 风格没有"异步信号"的概念
- loading/data/error 三段式的意图不如显式声明清晰
- `FutureSignal` 有 v6→v7 breaking change 历史，稳定性不如基础信号

### 3.4 参数化 Store（替代 Riverpod .family）

Riverpod 的 `.family` 用来创建"按参数区分的 provider 实例"。用 signals 实现等价功能：

```dart
// ✅ 使用 Map 管理参数化实例
class XtermStore {
  static final instance = XtermStore._();
  XtermStore._();

  final _terminals = <String, XtermSessionManager>{};

  XtermSessionManager forId(String id) {
    return _terminals.putIfAbsent(id, () => XtermSessionManager(id));
  }

  void dispose(String id) {
    _terminals.remove(id)?.dispose();
    activeIds.value = _terminals.keys.toSet();
  }

  final activeIds = signal(<String>{});
}
```

### 3.5 横向依赖处理

Store 之间可以互相引用，但**只允许单向引用**，避免循环依赖：

```
config_store  ←  llm_store  ←  session_store
     ↑
theme_store (不依赖其他 store)

layout_store (不依赖其他 store)
xterm_store  ←  theme_store（终端主题色）
```

示例：`llm_store` 需要读取 `configStore` 的配置路径：

```dart
class LlmStore {
  Future<void> loadProviders() async {
    // 直接引用 configStore
    final configPath = ConfigStore.instance.configPath.value;
    providers.value = await service.listProviders(configPath: configPath);
  }
}
```

**注意：** 引用其他 store 时通过 `XxxStore.instance` 访问，禁止循环引用。

### 3.6 生命周期管理

- **全局信号**不需要手动 dispose，随进程生命周期
- **`XtermSessionManager`** 等需要资源释放的对象，通过 `dispose()` 方法手动清理
- **`useExistingSignal`** 创建的绑定随 `HookWidget` 生命周期自动清理

### 3.7 迁移节奏

```
每次只做一步：写 store → 改所有引用该 store 的 UI → 删旧代码 → flutter analyze 确认无错误
```

**每一步都要能独立编译通过**，不要出现"改了一半编译不过"的状态。如果一次改动文件太多导致编译不过，说明步子迈大了，拆小。

### 3.8 测试策略

- **Store 层**：纯 Dart 类，可以直接写单元测试
- **UI 层**：`HookWidget` 的测试方式与普通 widget 测试一致
- **回归测试清单**：
  - [ ] 主题切换（亮/暗/跟随系统）
  - [ ] 会话选择与切换
  - [ ] 发送消息与流式输出
  - [ ] 模型选择器
  - [ ] 终端启动与交互
  - [ ] 设置页面（provider/model/MCP 配置）
  - [ ] 主题颜色自定义

---

## 四、参考

- [signals 文档](https://dartsignals.dev/)
- [signals_flutter SignalWidget](https://pub.dev/packages/signals_flutter)
- [signals_hooks useExistingSignal](https://pub.dev/packages/signals_hooks)
- [Pinia 文档](https://pinia.vuejs.org/)（概念参考，非 Dart）
