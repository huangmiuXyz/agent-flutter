# Flutter 项目代码组织与实现审查

> 审查范围：`lib/`、`test/`、`test_driver/`、`pubspec.yaml`、`Makefile` 以及 `docs/develp/`。  
> 本文的目标不是要求一次性重构全部代码，而是识别当前架构的边界问题，并给出可以分阶段落地的范式。

## 1. 结论摘要

当前项目已经搭建出一个可继续演进的基础：

- 有 `features/`、`theme/`、`router/`、`layout/` 等顶层职责目录；
- 主题已经使用 `ThemeExtension`，并通过 Riverpod 管理亮暗模式和颜色覆盖；
- 公共组件按类型归档，已经有按钮、文本、图标、列表、字段、菜单等基础抽象；
- 路由使用 `ShellRoute` 复用应用级布局；
- 已经有主题和终端键盘处理测试。

但当前实现仍处于“基础设施原型”阶段，目录名称与依赖方向尚未完全反映真实职责。最需要优先处理的不是新增更多组件，而是建立以下边界：

1. **公共层不能反向依赖开发层或业务层。** 当前 `lib/widgets/terminal/terminal_tabs.dart` 直接导入 `lib/dev/execute_panel.dart`。
2. **生产入口与 Demo 入口必须隔离。** 当前生产 router 导入 `DemoPage`，且默认路径是 `/demo`。
3. **终端业务应由 Terminal feature 持有。** 当前 PTY、终端状态、执行面板散落在 `widgets/terminal` 和 `dev` 中，并且执行面板通过 `ids.first` 猜测活动终端。
4. **主题需要一个唯一的解析链路。** 当前 `CustomTheme`、Flutter 默认 `ColorScheme` 和 Riverpod 的有效亮度各自承担一部分权威。
5. **文档、代码和规范需要建立契约同步机制。** 例如文档描述的 `AppButton`、`iconThickness`、多套字体文件和持久化主题设置，在当前实现中都不存在或尚未完成。
6. **生命周期和自动化门禁需要补齐。** PTY dispose/restart、Overlay、Controller/FocusNode 的释放，以及生成代码、格式、分析和全量测试流程都存在缺口。

总体建议：先做“依赖边界和可复现构建”的收敛，再整理 Terminal feature，之后统一主题和组件 API。不要在边界未稳定前继续扩大全局 `widgets/` 和 `theme/` 的职责。

---

## 2. 当前结构评估

### 2.1 当前目录表达的是 feature-first，但实际更接近 type-first

当前结构大致如下：

```text
lib/
├── features/
│   ├── chat/
│   └── settings/
├── widgets/
│   ├── button/
│   ├── card/
│   ├── field/
│   ├── list/
│   ├── terminal/
│   └── ...
├── dev/
├── layout/
├── router/
├── theme/
└── utils/
```

`features/chat` 和 `features/settings` 目前主要是页面占位；真正复杂的业务逻辑集中在：

- `lib/widgets/terminal/pty_manager.dart`
- `lib/widgets/terminal/command_runner.dart`
- `lib/widgets/terminal/xterm_provider.dart`
- `lib/widgets/terminal/xterm_widget.dart`
- `lib/widgets/terminal/terminal_tabs.dart`
- `lib/dev/execute_panel.dart`

因此，`lib/widgets/terminal` 并不是普通的公共 UI 组件目录，而是一个混合了 presentation、application 和 infrastructure 的 Terminal feature。

这本身不要求立即采用严格的 Clean Architecture。更实用的判断方式是：**目录应表达依赖方向和代码所有权，而不是只表达文件类型。**

### 2.2 推荐的依赖方向

建议把依赖关系收敛为：

```text
main / app
   ↓
router / app shell
   ↓
features ───────────────┐
   ↓                    │
shared widgets          │
   ↓                    │
 theme                  │
                        │
feature infrastructure ─┘
```

更具体的规则：

| 层 | 可以依赖 | 不应依赖 |
|---|---|---|
| `theme/` | Flutter 基础类型、纯值对象 | feature、dev、具体页面 |
| `widgets/` | `theme/`、Flutter 基础组件 | `features/`、`dev/`、全局业务 registry |
| `features/<name>/presentation` | 本 feature 的 application、shared widgets、theme | 其他 feature 的内部实现 |
| `features/<name>/application` | 本 feature 的 domain/infrastructure 接口 | Flutter 具体布局细节 |
| `features/<name>/infrastructure` | 平台插件、文件系统、PTY、网络等 | 页面 widget |
| `dev/` | shared widgets、用于演示的 feature API | 被 production router 反向引用 |
| `router/` | feature 的公开 route export | `dev/`（production router） |

建议在代码审查或 CI 中加入最简单的 import 约束：

```text
lib/widgets/** 不得导入 package:agent/dev/ 或 package:agent/features/
lib/router/** 不得导入 package:agent/dev/
```

如果未来需要跨 feature 共享，不要直接导入另一个 feature 的内部文件，而是提取稳定的接口或 shared component。

### 2.3 “先 feature-local，后提升 shared”的复用规则

一个组件满足以下条件后，再考虑放入 `lib/widgets/`：

1. 至少被两个相互独立的 feature 使用；
2. 不导入任何 `features/**` 或 `dev/**`；
3. 不包含产品业务名词；
4. 状态通过参数、回调或 controller 注入；
5. 有独立的 widget/unit test；
6. 调用方不需要了解其内部 `RenderBox`、Overlay 或 provider registry。

按此规则，当前代码可以这样归类：

| 当前代码 | 建议归属 | 说明 |
|---|---|---|
| `AppText`、`AppIcon`、按钮、卡片、分隔线 | shared widgets | 基础视觉原语 |
| `AppField`、`AppSelect`、`AppSwitch`、`AppList` | shared widgets | 保留，但需要收紧状态和生命周期 API |
| `ContextMenu`、`ResizeBox` | shared interaction/layout | 机制通用，但应去除全局生命周期和业务耦合 |
| `TerminalTabs`、`XtermTerminalWidget` | `features/terminal/presentation` | 绑定 xterm、PTY 和 shell |
| `PtyManager`、`CommandRunner`、shell 脚本 | `features/terminal/infrastructure` 或 application | 不是公共 widget |
| `ExecutePanel` | `features/terminal/presentation` | 它是终端能力，不是开发 Demo 专属能力 |
| `ColorThemeEditor`、组件 Demo | `dev/demos` | 只在开发入口提供 |
| FPS/性能监控工具 | `dev/tools` | 与组件 Demo 分开 |

---

## 3. P0：先修复架构边界

### 3.1 公共 Terminal widget 反向依赖 `dev`

证据：

- `lib/widgets/terminal/terminal_tabs.dart:12` 导入 `package:agent/dev/execute_panel.dart`；
- `lib/dev/execute_panel.dart:9` 又导入 `package:agent/widgets/terminal/xterm_provider.dart`。

当前依赖关系是：

```text
widgets/terminal/terminal_tabs.dart
        ↓
dev/execute_panel.dart
        ↓
widgets/terminal/xterm_provider.dart
```

这会形成不稳定的反向依赖：公共组件无法脱离开发页面复用，后续 production 构建也会被迫包含 Demo 代码。

**推荐改法：**

- 将 `ExecutePanel` 移到 `features/terminal/presentation/execute_panel.dart`；或
- 让 `TerminalTabs` 只负责 tab 和终端内容，通过参数注入底部面板：

```dart
TerminalTabs(
  bottomPanelBuilder: (context, activeTerminalId) {
    return ExecutePanel(terminalId: activeTerminalId);
  },
)
```

更推荐第一种：执行面板属于 Terminal feature，`TerminalTabs` 可以直接组合同一 feature 内的 presentation 组件，而 shared widgets 不再承担业务组合职责。

### 3.2 Production router 不应直接注册开发 Demo

证据：

- `lib/router/router.dart:5` 导入 `package:agent/dev/demo_page.dart`；
- `lib/router/router.dart:22` 将 `initialLocation` 设置为 `AppRoutes.demo`；
- `docs/develp/development_standards.md:147-160` 又规定 `dev/` 不参与生产构建。

这不仅是默认页选错的问题：只要 production `main.dart` 使用当前 router，Demo 及其依赖就是正式构建的一部分。

**推荐方案：独立入口：**

```text
lib/main.dart                 production 入口
lib/main_dev.dart             development 入口
lib/router/router.dart        production routes
lib/dev/dev_router.dart       Demo routes
```

运行开发组件展示：

```bash
flutter run -t lib/main_dev.dart
```

production router 的初始地址应指向 `AppRoutes.chat`。如果暂时不新增入口，也至少应：

- 将 Demo route 放入单独的 router factory；
- release 构建不导入 `dev_router.dart`；
- 为未知路径提供 `errorBuilder`；
- 在测试中锁定 production router 的初始地址。

仅使用 `if (kDebugMode)` 包裹 route 不足以表达清晰的构建边界，因为 Dart 编译单元仍可能导入开发代码。

### 3.3 不要让 `widgets` 目录成为业务服务容器

`PtyManager`、`CommandRunner` 和 `xterm_provider` 具有明确的业务/基础设施职责，却与 UI widget 混在同一目录。长期会造成：

- service 的生命周期由 widget 间接决定；
- 测试必须构造 UI 才能测试 PTY 行为；
- 其他 feature 误以为可以直接读取 terminal registry；
- provider 的作用域和所有权不清晰。

建议 Terminal feature 达到如下结构即可，不必一开始拆得过细：

```text
lib/features/terminal/
├── terminal_routes.dart
├── presentation/
│   ├── terminal_page.dart
│   ├── terminal_tabs.dart
│   ├── terminal_view.dart
│   └── execute_panel.dart
├── application/
│   ├── terminal_session.dart
│   └── terminal_session_provider.dart
├── infrastructure/
│   ├── pty_manager.dart
│   ├── command_runner.dart
│   ├── shell_scripts.dart
│   └── terminal_repository.dart
└── theme/
    └── terminal_palette.dart
```

`terminal_session_provider.dart` 可以成为 presentation 唯一依赖的入口；底层 PTY 实现通过接口注入，便于在测试中使用 fake。

---

## 4. P1：主题系统的建议范式

### 4.1 统一 `CustomTheme` 与 `ColorScheme` 的职责

当前 `lib/theme/app_theme.dart:6-13` 只设置了 `brightness`、背景色和 `CustomTheme` extension，没有显式设置 `colorScheme`、`textTheme`、`inputDecorationTheme`、`buttonTheme`、`dividerTheme` 等 Material 主题字段。

同时，`lib/app.dart:19-21` 将该 ThemeData 交给 MaterialApp，而 Material 和第三方组件仍会读取 Flutter 自动生成的默认 `ColorScheme`。

这会产生三套并行来源：

1. `CustomTheme` 自定义 token；
2. Flutter 默认 Material `ColorScheme`；
3. Riverpod 计算出的有效亮度。

**推荐范式：**

- `ColorScheme` 负责 Material 语义颜色；
- `CustomTheme` 负责应用专属角色、布局 token、终端 token 等扩展；
- `ThemeData` 在一个入口中由同一个 `ResolvedTheme` 生成；
- 组件不要随意在 `CustomTheme` 和 `Theme.of(context).colorScheme` 之间选择。

概念映射示例：

| `AppColors` | Material 语义 |
|---|---|
| `accent` / `onAccent` | `primary` / `onPrimary` |
| `danger` / `onDanger` | `error` / `onError` |
| `background` | `surface` 或 `surfaceContainerLowest` |
| `panel` / `cardBackground` | `surfaceContainer` / `surfaceContainerHigh` |
| `textPrimary` | `onSurface` |
| `border` / `borderSubtle` | `outline` / `outlineVariant` |
| `overlay` | `scrim` |

建议将主题装配抽象成类似以下链路：

```text
ThemeSettings
    ↓
ResolvedTheme（指定 Brightness 后的完整 token）
    ↓
buildThemeData(ResolvedTheme)
    ├── colorScheme
    ├── textTheme
    ├── iconTheme
    ├── inputDecorationTheme
    ├── buttonTheme
    └── extensions: [CustomTheme]
```

这样 `Fleather`、Material 输入框、对话框和其他第三方组件才有机会消费同一套基础主题。

### 4.2 主题设置目前没有持久化，需修正文档或补齐实现

`docs/develp/theme_system.md:11` 和 `:214-226` 将 `ThemeSettings` 描述为持久化状态，但 `lib/theme/provider.dart:14` 每次只返回 `const ThemeSettings()`，项目中也没有 repository、序列化或存储实现。

因此以下设置重启后会丢失：

- `themeMode`；
- `fontWeightValue`；
- `lightOverrides` / `darkOverrides`；
- `presetId`。

**推荐分层：**

```text
ThemeSettings（不可变用户意图）
        ↓
ThemeRepository（读取、保存、迁移）
        ↓
AsyncNotifier / ThemeNotifier
        ↓
ResolvedTheme
```

持久化格式建议：

- `ThemeMode` 保存为字符串；
- `AppColorRole` 保存为 `role.name`；
- `Color` 保存为 ARGB32 整数；
- 根对象包含 `version`，为未来字段迁移留出空间；
- 颜色编辑器连续拖动时 debounce 保存，避免每一帧写磁盘。

如果当前产品阶段不需要持久化，应直接把现有文档改为“进程内状态”，避免使用者形成错误预期。

### 4.3 强化深层不可变性

`ThemeSettings` 虽标记为 `@immutable`，但 `lib/theme/theme_settings.dart:29-40` 直接保存调用方传入的 Map。调用方可以在不执行 `state =` 的情况下修改该 Map，破坏 Riverpod 的状态契约。

建议在边界处复制并冻结：

```dart
Map<AppColorRole, int> _freezeOverrides(Map<AppColorRole, int> source) {
  return Map.unmodifiable(Map.of(source));
}
```

同样需要处理 `AppShadows` 的 `List<BoxShadow>`：

- `lib/theme/app_tokens.dart:187-229` 当前暴露可变 List；
- `CustomTheme.light` / `CustomTheme.dark` 是静态共享实例。

建议使用 `List.unmodifiable(List.of(...))`，并为主题值对象实现稳定的 `==` / `hashCode`，或使用 Freezed 生成深层不可变值对象。

### 4.4 `CustomTheme.of` 不应在 release 静默回退亮色

`lib/theme/custom_theme.dart:60-66` 在缺少 extension 时只在 debug 触发 assert，release 返回 `CustomTheme.light`。

风险是出现“Material 已经是暗色，但 CustomTheme 意外变成亮色”的混合主题，而且错误很难定位，尤其是在 root Overlay 或局部 Theme 下。

建议提供两个语义明确的 API：

```dart
CustomTheme.of(context)       // 缺失时抛出明确的 FlutterError
CustomTheme.maybeOf(context)  // 缺失时返回 null
```

测试和公共组件默认使用严格的 `of`。只有确实允许无主题上下文的基础工具才使用 `maybeOf`。

### 4.5 颜色角色应有单一元数据来源

当前 `AppColorRole` 有 26 个枚举值（`lib/theme/app_colors.dart:3-29`），但文档仍写“24 种”，颜色编辑器也没有完整暴露 `separator`、`cardBackground`、`cardBorder` 等角色（见 `lib/dev/color_theme_editor.dart` 的角色分组）。

建议为角色定义一份元数据，统一驱动：

```text
role
label
category
editable
supportsAlpha
foregroundRole
contrastTarget
```

由此生成或校验：

- 编辑器分组；
- 文档表格；
- 持久化白名单；
- 对比度测试；
- 亮色/暗色完整性测试。

至少应增加断言/测试：

```text
AppColorRole.values == light.keys == dark.keys
```

新增角色时，`apply()` 和 `lerp()` 已经是 map 通用实现，不需要按文档所述手动逐字段修改；文档应同步修正。

### 4.6 修复 token 的实际消费链和透明度语义

目前存在“可编辑但不生效”的 token：

- `shadow` 在编辑器中可修改，但 `AppShadows.forBrightness()` 使用硬编码的 `Colors.black`（`lib/theme/app_tokens.dart:195-218`）；
- `menuHover` 已定义，但菜单项实际主要消费通用 `hover`（`lib/widgets/list/app_list.dart`、`lib/widgets/context_menu/context_menu.dart`）；
- `overlay` 默认带 alpha（`lib/theme/app_colors.dart:83,111`），颜色编辑器候选颜色却都是不透明色。

建议：

1. 要么让每个可编辑 token 都有完整消费链和测试；
2. 要么从编辑器中移除尚未支持的角色；
3. 对颜色区分“纯色”和“带 alpha 的颜色”；
4. 为 overlay 提供 alpha 控件，或拆成 `overlayColor + overlayOpacity`；
5. 阴影可建模为颜色 token 加独立 opacity/geometry token；
6. 增加主题覆盖后的截图或 widget 测试，确认实际组件颜色发生变化。

### 4.7 建立可访问性对比度契约

`lib/theme/app_colors.dart:78-79,106-107` 的默认 `danger` 与白色 `onDanger` 在部分场景下对比度不足；而 `AppField` 错误文本直接使用 danger 色（`lib/widgets/field/app_field.dart`）。

`ThemeNotifier._bestForeground()` 只选择黑/白中对比度较高的一方，并不保证普通正文达到 WCAG 要求，也没有统一处理 `success` / `warning` 的前景色。

建议：

- 明确每个状态色的使用场景：文字色、背景色、按钮填充色不能共用一个无约束 token；
- 为 `success` / `warning` 增加明确的 `onSuccess` / `onWarning`，或限制其只能作为文字/边框色；
- 对正文、按钮、错误提示分别做对比度测试；
- 颜色编辑器保存前校验对比度并给出反馈，而不是只计算“黑白谁更好”。

### 4.8 拆分全局 token 与 feature-specific metrics

`lib/theme/app_tokens.dart:71-108` 的 `AppControls` 同时包含通用控件高度、switch 尺寸、dialog 宽度、context menu 宽度、tab 宽度和 execute panel 高度。

建议拆成：

```text
AppSpacingTokens       基础间距比例
AppLayoutTokens        页面和 overlay 布局
AppControlTokens       通用控件尺寸
AppOverlayMetrics      dialog/menu 尺寸
TerminalLayoutMetrics  tab/terminal/execute panel 尺寸
AppTypographyTokens    语义排版
AppElevationTokens     阴影层级
```

原则是：只有跨多个 feature 且属于设计系统的值，才放入全局 `CustomTheme`；Terminal tab 和 ExecutePanel 的尺寸应优先由 Terminal feature 持有。

### 4.9 统一主题亮度权威和 API 语义

`MaterialApp` 由 Flutter 根据 `themeMode` 解析亮度（`lib/app.dart:19-21`），而终端等代码又使用 `effectiveBrightnessProvider`（`lib/theme/provider.dart:84-91`）。在测试 override 或复杂嵌套主题时，两者可能出现不同结果。

建议让 `resolvedThemeProvider` 成为唯一权威，MaterialApp 与 feature adapter 都从它取值，系统亮度则作为可注入输入：

```text
SystemBrightnessSource（可替换）
        ↓
effectiveBrightnessProvider
        ↓
resolvedThemeProvider
        ├── MaterialApp
        ├── terminal palette
        └── third-party adapters
```

此外，`ThemeNotifier.toggle()`（`lib/theme/provider.dart:20-25`）是“根据当前有效亮度设置反向显式模式”，而 Demo 中又实现了 `system → light → dark → system` 三态循环。建议拆成明确命名的方法：

- `setThemeMode(mode)`：设置三态模式；
- `cycleThemeMode()`：循环 system/light/dark；
- `toggleEffectiveBrightness()`：只在实际亮暗间切换。

命名、UI 行为和文档必须保持一致。

### 4.10 清理字体和主题文档漂移

`pubspec.yaml:42-46` 只注册了一个 `JetBrainsMono-Regular.ttf`，但 `docs/develp/theme_system.md:144-155` 描述了多套字重文件和 `fontWeightToFamily()`，源码 `AppTypography` 实际只是设置 `fontWeight`（`lib/theme/app_tokens.dart:129-171`）。

二选一：

- 补齐并正确声明实际字重文件；
- 或删除不存在的字体映射说明，明确使用 Flutter 合成字重。

同时建议将排版从单独字号 token 升级为语义样式对象（字号、字重、行高、字族一起定义），避免 `w500`、`w600` 散落在组件中。

---

## 5. P1：公共组件 API 与生命周期

### 5.1 统一按钮公开 API，或者立刻修正文档

`docs/develp/components.md:157-214` 和 `docs/develp/development_standards.md:23-28` 描述了不存在的 `AppButton` / `ButtonVariant` / `app_button.dart`；实际实现是：

- `lib/widgets/button/app_primary_button.dart`
- `lib/widgets/button/app_secondary_button.dart`
- `lib/widgets/button/app_text_button.dart`
- `lib/widgets/button/app_icon_button.dart`
- `lib/widgets/button/button_base.dart`

这会直接导致新代码按文档导入失败。

推荐保留一个统一入口：

```dart
AppButton(
  variant: AppButtonVariant.primary,
  size: AppButtonSize.md,
  label: '确认',
  icon: AppIconName.check,
  onPressed: onPressed,
)
```

内部可以继续复用四种实现。迁移期间旧类可作为 deprecated wrapper。API 契约应明确：

- `iconOnly` 是否必须有 icon；
- 非 `iconOnly` 是否必须有 label/child；
- `disabled` 与 `onPressed == null` 的优先级；
- tooltip、semantic label、最小命中区域；
- 完整 `ButtonStyle` 是否允许覆盖设计系统，还是只允许有限的扩展参数。

如果暂时不统一，则应立即把文档改成当前四个类，不能同时维护两套 API 叙述。

### 5.2 `AppIcon` 应避免字符串静默回退

`lib/widgets/icon/app_icon.dart` 使用字符串 registry，未知名称会静默回退为 `helpCircle`。这会把拼写错误伪装成合法 UI；当前 Demo 已出现文档/registry 可能不一致的图标名。

建议按优先级选择：

1. 用 `enum AppIconName` 或生成的 typed registry；
2. 如果必须保留字符串，debug 模式 assert，release 记录一次可定位日志；
3. 加入 `semanticLabel` / `excludeFromSemantics`；
4. 用测试遍历公开名称，确保每个名称有映射。

文档还描述 `iconThickness` 和 0–600 的变体，但当前 `AppIcon` 构造函数没有该参数，应该实现或删除该承诺。

### 5.3 明确 `AppText.style` 的 escape hatch

规范规定 `AppText.style` 不应覆盖 `fontSize`，但实现直接 merge style（`lib/widgets/text/app_text.dart`），调用方仍然可以覆盖字号和字重。

建议二选一：

- 移除完整 `style`，只提供 `letterSpacing`、`decoration` 等有限参数；
- 保留 `style` 作为明确的高级 escape hatch，并在 debug 模式检查 `fontSize` / `fontWeight`，同步修改规范。

不要让文档写成“禁止”，实现却无法保证。

### 5.4 Overlay 和 ContextMenu 应由实例 controller 持有

`lib/widgets/context_menu/context_menu.dart:47-80` 使用全局静态 `OverlayEntry`。这意味着整个应用只有一个菜单实例，route 切换、窗口销毁和多窗口场景没有明确 owner。

建议使用：

```text
MenuController
  ├── show()
  ├── dismiss()
  └── dispose()
```

结合 `OverlayPortal` 或 `CompositedTransformTarget/Follower`，由一个 host widget 负责插入和移除 entry。菜单模型与行为也可以分离：

- model 只描述 label、icon、enabled、shortcut、submenu；
- feature 负责把 action ID 映射为命令；
- controller 负责展示和关闭。

同时统一坐标策略：当前代码把菜单插入 root overlay，却使用 `View.of(context)` 的物理尺寸（`context_menu.dart:132-145`）。需要明确是使用局部 overlay，还是 root overlay 加显式主题和 viewport 适配。

### 5.5 修复 `AppSelect` 的 overlay 竞态和禁用态

`lib/widgets/select/app_select.dart:94-164` 的 `addPostFrameCallback` 与 cleanup 之间存在竞态：组件可能在 callback 执行前关闭或卸载，`entry.remove()` 也没有记录是否已经 insert。

overlay builder 还会捕获打开时的 `custom`、`options` 和 `value`，打开期间主题或选项更新不一定同步。

此外，`AppSelect.disabled` 最终传给 `AppField` 的却是 `enabled: true`（`app_select.dart:176-192`），会出现“不能点但看起来仍启用”的视觉不一致。

建议：

- 使用 `OverlayPortal` 或专门的 dropdown controller；
- 记录 entry 的 inserted/disposed 状态；
- overlay 从 controller/state 读取最新数据；
- 将 `enabled` 正确传给 `AppField`；
- `menuMaxHeight` 使用主题 metric，而不是默认硬编码 `300`；
- 复用并正确管理 `TextEditingController`，避免每次 selected label 变化都创建新 controller。

### 5.6 修复 Dialog、Field、Switch 的契约漂移

**Dialog：** `AppDialog.show` 声明返回 `Future<bool?>`，但确认和取消都调用无参数 `Navigator.pop()`，因此通常只返回 null。应统一为：

```dart
确认 -> Navigator.pop(context, true)
取消 -> Navigator.pop(context, false)
遮罩/返回 -> null
```

或改成纯 callback API，不要同时承诺两种控制模型。

**Field：** `AppField` 维护 focus 状态，但边框样式只处理 error/hover，focus 状态没有视觉表现。建议定义状态优先级：`disabled > error > focused > hover > normal`，并补充键盘 focus 测试。

**InlineField：** `lib/widgets/field/inline_field.dart` 用 `useMemoized` 创建 controller/focus node，生命周期和 effect 闭包不够清晰。内部创建的对象必须由 hook 自动释放或 cleanup 显式释放；同时明确 `onSubmitted` 在 Enter、focus loss 时的语义。

**Switch：** 文档将 `onChanged == null` 描述为只读，但实现把它作为 disabled。建议增加独立的 `readOnly` / `disabled`，或统一修改文档和行为；同时补充 `Semantics(toggled: ..., enabled: ...)`。

### 5.7 列表键盘导航不要依赖运行时类型或全局键盘监听

`lib/widgets/list/app_list.dart:58-76` 通过 child 的 runtimeType 判断哪些项目参与键盘导航，自定义列表项和嵌套列表很容易失效。另一个风险是 `HardwareKeyboard` 全局 handler：多个可导航列表同时存在时可能同时响应同一事件。

建议：

- 用显式的 `AppListItemData<T>` 或 `FocusableActionDetector` 描述可导航项；
- 用 `Focus`、`Shortcuts`、`Actions` 和 `FocusTraversalGroup` 让焦点决定事件归属；
- 大列表提供 `AppListView.builder`，不要默认用 `Column`；
- `BorderRadiusGeometry` API 与实现保持一致，避免在 `app_list.dart` 中强制 cast 成 `BorderRadius`。

### 5.8 避免普通 `AppCard` 默认走 intrinsic + scroll

`lib/widgets/card/app_card.dart` 的默认组合同时使用 `IntrinsicWidth`、`ConstrainedBox` 和 `SingleChildScrollView`。普通静态卡片会承担不必要的布局和滚动开销。

建议将内容滚动设为显式能力：

```dart
AppCard(
  scrollable: true,
  maxHeight: menuMaxHeight,
  child: ...,
)
```

普通卡片默认不包 scroll；菜单、dialog、大文本区域按需开启。应增加静态卡片、菜单面板和超长内容三类布局测试。

---

## 6. P1：Terminal feature 的状态和生命周期

### 6.1 活动终端必须显式传递，不要使用 `ids.first`

`TerminalTabs` 在 `lib/widgets/terminal/terminal_tabs.dart:21-39,54-69` 自己维护 `activeIndex`，但 `ExecutePanel` 在 `lib/dev/execute_panel.dart:21-46` 从全局 registry 取 `ids.first`。

这会导致：

- 当前可见 tab 与执行命令的 tab 不一致；
- 切换、新增、关闭 tab 后可能操作旧终端；
- `Ctrl+C` 发到错误的 PTY；
- registry 集合顺序被错误地当成活动状态。

推荐 API：

```dart
TerminalTabs(
  activeTerminalId: activeId,
  onActiveTerminalChanged: onActiveChanged,
)

ExecutePanel(terminalId: activeId)
```

更进一步，可以传入 `TerminalSession` / controller，而不是让 UI 查询全局 registry。活动 session 应只有一个 owner，其他组件通过只读状态或命令接口访问。

### 6.2 给 `PtyManager` 建立明确状态机和 restart policy

`lib/widgets/terminal/pty_manager.dart:118-123` 在任意 `exitCode` 完成后调用 `_scheduleRestart()`；`dispose()`（:150-152,315-347）没有 `_disposed` 标志。

潜在时序：

```text
provider dispose
   ↓
_cleanup() kill PTY
   ↓
exitCode Future 完成
   ↓
_scheduleRestart()
   ↓
start() 再次创建 shell
```

建议引入至少以下状态：

```text
created → running → stopping → disposed
```

并遵循：

- `dispose()` 后 `start()` 直接拒绝；
- exit callback 首先检查 `_disposed`；
- 显式关闭、正常 `exit` 和异常崩溃分别处理；
- 只有异常退出才自动重启；
- `restartOnCrash`、最大重启次数和退避策略成为显式配置；
- 重启 timer 也必须在 dispose 时取消。

### 6.3 修复 `CommandRunner.dispose()` 使 active Future 完成

`lib/widgets/terminal/command_runner.dart:24-107` 的 `execute()` 会等待 shell marker；`dispose()`（:110-117）只取消订阅并关闭 stream，没有完成当前 `Completer`。

如果命令执行中 terminal 被关闭，调用方可能永久等待。

建议维护 active execution 对象，在 dispose 时统一：

- 取消订阅和 timeout；
- `completeError(TerminalDisposedException())`；
- 清理 active 集合；
- 后续 `feedOutput` / `execute` 在 disposed 状态下明确抛错。

同时补充并发执行策略：是禁止并发、排队，还是每个命令独立关联 marker，应该写成 API 契约。

### 6.4 正确管理 FocusNode 和 PTY 的 widget 生命周期

`lib/widgets/terminal/xterm_widget.dart:30-50` 使用 `useRef(FocusNode())`，但 `useRef` 不负责释放 `FocusNode`；启动 effect 也没有对应 cleanup。

建议使用自动释放的 focus hook，或在 effect cleanup 中显式 dispose。对于 tab 的 `IndexedStack`：

- 明确隐藏 tab 是否保持 PTY/session；
- 关闭 tab 时由 session owner 负责 dispose；
- `visible == false` 时不要抢 focus；
- PTY 是否延迟到首次进入 terminal 页面才创建。

---

## 7. P1/P2：入口、平台和布局

### 7.1 明确支持平台，并隔离桌面插件

`lib/main.dart:13-26` 无条件调用 `windowManager.ensureInitialized()`；`lib/app.dart:24` 无条件使用 `VirtualWindowFrameInit`；`lib/layout/main_layout.dart:1-55` 直接导入 `dart:io` 和 `window_manager`。

如果项目是纯桌面应用，应在 README 和构建配置中明确 Linux/macOS/Windows 支持矩阵，不要让 Android/iOS 目录暗示移动端也可运行。

如果需要跨平台：

- 只在桌面平台初始化 window manager；
- `MainLayout` 使用平台适配层；
- Web 避免无条件导入 `dart:io`；
- 移动端使用普通 app shell，不走窗口标题栏组件。

建议结构：

```text
layout/
├── main_layout.dart
└── window_chrome/
    ├── window_chrome.dart
    ├── desktop_window_chrome.dart
    └── mobile_window_chrome.dart
```

### 7.2 启动流程要等待 Future，并统一错误处理

`lib/main.dart:25-35` 没有 await `waitUntilReadyToShow()`，异步 callback 内的 `show()` / `focus()` 错误也没有明确处理；Zone handler 还丢弃了 stack。

建议：

- 将 binding、窗口配置、窗口显示拆成可测试的初始化步骤；
- 明确窗口插件初始化失败时是降级启动还是退出；
- 输出完整 error + stack；
- 配置 `FlutterError.onError` 和 `PlatformDispatcher.instance.onError`；
- 将启动逻辑封装为 `AppBootstrap`，让 widget test 可以跳过真实窗口插件。

### 7.3 `ContentFrame` 应基于当前窗口约束

`lib/utils/layout_utils.dart:4-9` 使用主显示器物理尺寸的一半作为阅读宽度，`lib/widgets/content_frame/content_frame.dart:15-24` 直接使用它。

窗口缩小或多显示器场景下，内容宽度可能大于当前可用窗口，产生溢出或不合理布局。

建议使用：

- `LayoutBuilder.constraints.maxWidth`；
- `MediaQuery.sizeOf(context)`；
- `maxWidth` + 响应式边距；
- 仅把显示器信息用于窗口级行为，不用于普通页面内容宽度。

增加小窗口、高 DPI、多显示器和窗口 resize 测试。

---

## 8. P2：工程化、依赖和测试

### 8.1 明确生成代码策略

`lib/theme/provider.dart` 和 `lib/widgets/terminal/xterm_provider.dart` 依赖 `.g.dart`，但 `.gitignore:36-38` 忽略所有生成文件。当前本地有生成文件不代表干净 checkout 可直接运行。

建议二选一：

1. 继续忽略生成文件，但让 `analyze`、`test`、`build` 的前置步骤明确执行：

   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

2. 将生成文件纳入版本控制，减少首次构建的隐式前置条件。

无论选择哪种方式，都应在 README、Makefile 和 CI 中统一写明，并增加一次 clean checkout 验证。

### 8.2 补齐 Makefile 质量门禁

当前 `Makefile` 只有 `run/build/watch/clean`，但：

- `.PHONY` 声明了没有实现的 `patch`；
- `run` 注释称“应用 patch”，实际没有 patch 命令；
- `clean` 中 `find . -name "*.freezed.dart" -o -name "*.g.dart" -delete` 存在运算优先级问题；
- build_runner 没有 `--delete-conflicting-outputs`；
- 没有 `format`、`analyze`、`test`、`verify` 目标。

建议至少提供：

```text
make generate
make format-check
make analyze
make test
make verify
make run
```

其中 `verify` 顺序固定为：

```text
generate → format-check → analyze → test
```

生成文件清理应限制在 `lib/`，并正确使用 find 括号，避免误删其他文件。

### 8.3 固定 Flutter SDK 和依赖边界

`pubspec.yaml:6-7` 只声明 Dart SDK，没有声明 Flutter 最低版本；项目使用了较新的 Flutter API 和桌面插件，建议补充明确的 Flutter 约束，并在 README/CI 固定 channel 或版本。

同时清理没有实际 import 的 direct dependency，例如当前尚未使用的 Freezed 相关依赖；不要为了“未来可能使用”长期保留 prerelease 生成器或模型包。依赖升级前应先运行：

```bash
flutter pub outdated
flutter pub deps
```

并记录需要保留每个 direct dependency 的理由。

### 8.4 建立真实的测试分层

当前已有主题测试和终端键盘测试，但缺少入口、路由、Overlay、PTY 和平台适配测试。建议按层补齐：

**纯 Dart/unit test：**

- `ThemeSettings` 序列化、迁移、不可变性；
- 颜色角色完整性和对比度；
- `CommandRunner` marker 解析、timeout、dispose；
- PTY restart policy；
- terminal selection 算法。

**Widget test：**

- `resolveTheme` 注入 `ColorScheme` 与 `CustomTheme`；
- AppButton variant/disabled/pressed；
- AppDialog 返回 `true/false/null`；
- AppSelect disabled、options 更新和 overlay 清理；
- ContextMenu dismiss 和 route dispose；
- AppField focus/error/disabled；
- ContentFrame 小窗口布局。

**Integration test：**

- `AgentApp` 启动和 production 初始路由；
- dev entry 的 Demo route；
- 桌面窗口初始化和标题栏；
- Terminal session 创建、切换、关闭；
- 至少一个受支持桌面的 smoke test。

终端选区测试当前需要先明确契约：测试名称、期望键序列和实现注释对宽字符、尾部 padding、Delete/Backspace 方向存在不一致。建议同时断言最终 buffer/cursor 状态，不要只断言原始按键序列。

### 8.5 补充 README 和文档索引

`README.md` 仍是模板占位内容，建议至少加入：

- 项目定位和支持平台；
- Flutter/Dart 版本；
- `flutter pub get` 和代码生成；
- `make run` / `make verify`；
- 目录结构和依赖规则；
- Demo 入口；
- 终端 shell 支持范围；
- 已知限制和测试命令；
- `docs/develp/` 文档入口。

`docs/develp` 名称疑似是 `develop` 的拼写错误。建议在一次文档整理中统一命名，避免只改目录导致外部链接失效；在此之前可以增加文档索引，而不是让用户依赖猜路径。

---

## 9. 推荐的目标目录与示例 API

### 9.1 目标目录（渐进式版本）

不建议一次性做大规模搬迁。可以先达到以下状态：

```text
lib/
├── app/
│   ├── app.dart
│   └── bootstrap.dart
├── features/
│   ├── chat/
│   │   ├── presentation/
│   │   └── chat_routes.dart
│   ├── settings/
│   │   ├── presentation/
│   │   └── settings_routes.dart
│   └── terminal/
│       ├── presentation/
│       ├── application/
│       ├── infrastructure/
│       ├── theme/
│       └── terminal_routes.dart
├── shared/
│   ├── theme/          # 或继续保留 lib/theme，关键是边界清晰
│   ├── widgets/
│   ├── layout/
│   └── utils/
├── router/
│   ├── app_router.dart
│   └── dev_router.dart
├── dev/
│   ├── demos/
│   └── tools/
├── main.dart
└── main_dev.dart
```

如果当前项目不想新增 `shared/`，可以继续使用 `lib/widgets`，但必须执行同样的依赖规则。目录重命名不是目的，**减少反向依赖和明确所有权才是目的。**

### 9.2 Terminal API 示例

```dart
class TerminalTabs extends StatelessWidget {
  const TerminalTabs({
    required this.sessions,
    required this.activeSessionId,
    required this.onActiveSessionChanged,
    super.key,
  });

  final List<TerminalSession> sessions;
  final String activeSessionId;
  final ValueChanged<String> onActiveSessionChanged;
}

class ExecutePanel extends StatelessWidget {
  const ExecutePanel({required this.terminalId, super.key});

  final String terminalId;
}
```

页面层持有 `activeSessionId`，执行面板只接收目标 ID，不读取 registry 的“第一个元素”。

### 9.3 主题 API 示例

```dart
ThemeSettings        // 可序列化的用户意图
ResolvedTheme        // 指定 Brightness 后的完整 token
buildThemeData(...)  // 唯一 ThemeData 装配入口

CustomTheme.of(context)       // 严格获取
CustomTheme.maybeOf(context)  // 明确允许缺失
```

组件内部的推荐边界：

```text
build(context)
  → 获取 CustomTheme / ColorScheme
  → 调用纯 resolver 计算样式
  → 组装 Flutter widget
```

这样颜色、尺寸和状态样式可以在不启动完整 widget 树的情况下测试。

---

## 10. 分阶段落地路线

### 阶段 0：建立可复现基线（优先级最高）

1. 明确支持平台和 Flutter 版本；
2. 决定生成文件是否入库；
3. 修复全量测试失败，先定义 terminal selection 行为；
4. 增加 `make verify`；
5. 补充 README 的运行和验证步骤；
6. 建立 production/dev 两个入口的验收测试。

**验收：**干净 checkout 能生成、分析、测试，且 production 默认不会进入 Demo。

### 阶段 1：切断依赖反向引用

1. 移动 `ExecutePanel` 到 Terminal feature；
2. production router 不再导入 `dev`；
3. 将 Demo 拆到 `main_dev.dart` / `dev_router.dart`；
4. 在 CI 检查 `widgets → dev/features` 和 `router → dev` 的 import 违规。

**验收：**shared widgets 可以在没有 `dev/` 的情况下被测试和复用。

### 阶段 2：收敛 Terminal ownership

1. 显式建模 active session；
2. 去掉 `ids.first`；
3. 给 `PtyManager` 增加 disposed guard 和 restart policy；
4. 让 `CommandRunner.dispose()` 完成 active Future；
5. 正确释放 FocusNode、controller、timer 和 PTY；
6. 为 session 增加 fake infrastructure 测试。

**验收：**关闭 tab、正常退出 shell、PTY 崩溃和页面卸载都不会创建幽灵进程或挂起 Future。

### 阶段 3：统一主题契约

1. 显式接入 `ColorScheme`；
2. 统一 MaterialApp 与 Riverpod 的有效亮度；
3. 主题设置接入 repository/持久化；
4. 冻结 map/list，补充值相等；
5. 补齐颜色角色元数据、alpha、shadow、menuHover 消费链；
6. 增加对比度和亮暗两套完整测试；
7. 修正字体、token 和文档漂移。

**验收：**修改任一可编辑角色后，所有声明使用该角色的组件都实际更新；应用重启后设置仍符合产品预期。

### 阶段 4：稳定公共组件 API

1. 统一 `AppButton` 或同步文档到真实 API；
2. 类型化 `AppIcon` registry；
3. 明确 `AppText.style` escape hatch；
4. 重构 Overlay controller；
5. 修复 Dialog/Select/Field/Switch/List 契约；
6. 为每个公开组件保留最小用法和状态测试。

**验收：**文档中的每个公开类、构造参数和示例都能在当前源码中找到并通过分析。

---

## 11. 建议的检查清单

以后新增 feature 或公共组件时，可以在 PR 中逐项确认：

### 目录和依赖

- [ ] 代码首先放在 feature-local，确认有跨 feature 复用后再提升 shared；
- [ ] `widgets/` 不依赖 `dev/` 或 feature 内部实现；
- [ ] infrastructure 不导入页面 widget；
- [ ] production router 不导入 dev；
- [ ] 平台插件位于适配层，而不是普通 shared widget。

### 主题和组件

- [ ] 所有颜色、尺寸、间距有明确 token 归属；
- [ ] 可编辑 token 有完整的消费链和测试；
- [ ] `ColorScheme` 与 `CustomTheme` 的职责明确；
- [ ] controller、FocusNode、OverlayEntry、Timer 有明确 owner 和 dispose；
- [ ] disabled、readOnly、focused、hover、pressed 状态契约一致；
- [ ] 无效 icon/route/option 不会静默回退到看似正常的 UI。

### 工程和验证

- [ ] 生成代码策略在 clean checkout 可复现；
- [ ] `format-check`、`analyze`、unit/widget test 已加入门禁；
- [ ] 关键 feature 有 integration smoke test；
- [ ] 文档示例中的类名和构造参数真实存在；
- [ ] 变更后的行为有对应测试或明确记录为待办。

---

## 12. 最终建议

如果只能先做五件事，建议按以下顺序：

1. **拆分 production 和 dev router/entrypoint，并把默认路径改为真正的产品页面。**
2. **移除 `widgets/terminal → dev/execute_panel` 的反向依赖，明确 Terminal feature 的所有权。**
3. **修复 active terminal、PTY dispose/restart 和 `CommandRunner` 未完成 Future。**
4. **让 `ThemeData` 显式接入 `ColorScheme`，并决定主题设置是否真正持久化。**
5. **建立 `make verify` 和文档/API 同步规则，先修复当前全量测试、格式和生成代码问题。**

当前项目的方向并不需要推倒重来；核心工作是把已经存在的抽象从“可用原型”提升为“有明确边界、生命周期和契约的基础设施”。只要先收敛依赖方向和状态所有权，后续增加 Chat、Settings、Terminal 等 feature 时，维护成本会明显低于继续把业务能力放进 `widgets/` 或 `dev/`。
