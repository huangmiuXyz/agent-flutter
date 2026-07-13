# 开发规范

## 目录

1. [组件优先原则](#1-组件优先原则)
2. [状态管理规范](#2-状态管理规范)
3. [主题与样式规范](#3-主题与样式规范)
4. [目录结构规范](#4-目录结构规范)
5. [禁止使用原生小部件](#5-禁止使用原生小部件)
6. [颜色使用规范](#6-颜色使用规范)
7. [间距与尺寸规范](#7-间距与尺寸规范)
8. [文本变体规范](#8-文本变体规范)
9. [路由管理规范](#9-路由管理规范)
10. [Provider 规范](#10-provider-规范)

---

## 1. 组件优先原则

能用组件的地方必须用组件。所有 UI 元素优先使用项目中封装好的公共组件。

| 场景 | 必须使用 | 禁止使用 |
|------|----------|----------|
| 文本 | `AppText` | `Text` |
| 图标 | `AppIcon` | `Icon`、`Icons.xxx`、`LucideIcons.xxx` |
| 按钮 | `AppButton` | `TextButton`、`IconButton`、`FloatingActionButton` |
| 卡片容器 | `AppCard` | `Container` + 手动装饰 |
| 列表项 | `AppListItem` | `ListTile`、手动 `Row` |
| 列表容器 | `AppList` | 手动 `Column` + 循环 |
| 分隔线 | `AppDivider` | `Divider`、`VerticalDivider` |

## 2. 状态管理规范

### 2.1 局部状态 — flutter_hooks

简单的 UI 局部状态优先使用 `flutter_hooks`：

```dart
class MyWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final isHovered = useState(false);
    final count = useRef(0);

    return ...;
  }
}
```

| 场景 | 使用 |
|------|------|
| 简单布尔/数值状态 | `useState` |
| 需要引用但不触发 rebuild | `useRef` |
| 副作用/生命周期 | `useEffect` |
| 动画 | `useAnimationController` |

### 2.2 全局/共享状态 — Riverpod + @riverpod

全局状态或跨组件共享状态使用 `hooks_riverpod`，必须使用 `@riverpod` 注解配合 `riverpod_generator` 代码生成，禁止手写 `Provider`、`StateNotifierProvider`、`StateProvider` 等底层 API。

```dart
part 'my_provider.g.dart';

@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  int build() => 0;

  void increment() => state++;
}
```

在组件中使用：

```dart
class MyWidget extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myNotifierProvider);
    return ...;
  }
}
```

### 2.3 Widget 基类选择

| 场景 | 基类 |
|------|------|
| 无 hooks、无 provider | `StatelessWidget` |
| 有 hooks、无 provider | `HookWidget` |
| 无 hooks、有 provider | `ConsumerWidget` |
| 有 hooks、有 provider | `HookConsumerWidget` |

## 3. 主题与样式规范

所有样式使用 `CustomTheme` 主题变量 token，禁止出现数字等魔法值。

### 3.1 获取主题

```dart
final custom = CustomTheme.of(context);
```

### 3.2 主题 token 总览

| 类别 | 属性 | Token 示例 |
|------|------|-----------|
| 颜色 | `custom.colors` | `.background`, `.panel`, `.textPrimary`, `.textSecondary`, `.accent`, `.border`, `.success`, `.warning`, `.danger` 等 |
| 间距 | `custom.spacing` | `.xs` (4), `.sm` (8), `.md` (16), `.lg` (24), `.xl` (32) |
| 圆角 | `custom.radii` | `.xs` (4), `.sm` (8), `.md` (12), `.full` (999) |
| 控件高度 | `custom.controls` | `.smallHeight` (24), `.mediumHeight` (32), `.largeHeight` (40) |
| 阴影 | `custom.shadows` | `.small`, `.medium`, `.large` |
| 字号 | `custom.typography` | `.captionSize` (12), `.bodySize` (14), `.subtitleSize` (16), `.titleSize` (18), `.heading2Size` (24), `.heading1Size` (32) |

## 4. 目录结构规范

```
lib/
├── features/           # 业务功能页面（按 feature 组织）
│   ├── chat/           # 聊天功能
│   │   └── chat_page.dart
│   └── settings/       # 设置功能
│       └── settings_page.dart
├── layout/             # 应用级布局组件
│   └── main_layout.dart
├── router/             # 路由配置
│   └── router.dart
├── theme/              # 主题与样式定义
│   ├── app_colors.dart
│   ├── app_theme.dart
│   ├── app_tokens.dart
│   ├── custom_theme.dart
│   ├── provider.dart
│   └── theme_settings.dart
├── utils/              # 工具函数
│   └── shell_utils.dart
├── widgets/            # 公共可复用组件（按类型组织）
│   ├── button/
│   ├── card/
│   ├── context_menu/
│   ├── divider/
│   ├── icon/
│   ├── list/
│   ├── terminal/
│   └── text/
├── dev/                # 开发调试页面（非生产）
│   ├── demo_page.dart
│   ├── button_demo.dart
│   └── ...
├── app.dart
└── main.dart
```

**规则**：
- 业务页面放在 `features/<name>/` 下，同一 feature 的页面、provider、model 放在同一目录
- 公共组件放在 `widgets/<type>/` 下，每个组件类型一个子目录
- 主题与样式全部集中在 `theme/` 下
- 工具类放在 `utils/` 下
- 开发调试页面放在 `dev/` 下，不参与生产构建

## 5. 禁止使用原生小部件

禁止直接使用 Flutter Material 原生小部件替代应用组件。

### ❌ 禁止

```dart
// 文本
Text('Hello', style: TextStyle(...))

// 图标
Icon(Icons.close, size: 18)
Icon(LucideIcons.settings)

// 按钮
TextButton(onPressed: ..., child: Text('...'))
IconButton(onPressed: ..., icon: Icon(...))
FloatingActionButton(onPressed: ..., child: Icon(...))

// 列表
ListTile(leading: ..., title: Text(...))

// 容器
Container(
  decoration: BoxDecoration(
    color: ...,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(...),
    boxShadow: [...],
  ),
  child: ...,
)

// 分隔线
Divider()
VerticalDivider()
```

### ✅ 正确

```dart
// 文本
AppText('Hello', variant: AppTextVariant.body)

// 图标
AppIcon('x', size: custom.fontSizeTitle)

// 按钮
AppButton(text: '确定', onPressed: () {})
AppButton(icon: 'settings', variant: ButtonVariant.iconOnly, onPressed: () {})

// 列表
AppListItem(icon: 'terminal', label: '终端', onTap: () {})

// 容器
AppCard(child: ...)

// 分隔线
AppDivider()
AppDivider(axis: Axis.vertical)
```

## 6. 颜色使用规范

所有颜色必须通过 `AppColorRole` 枚举从主题系统获取，禁止硬编码颜色值。

### ❌ 禁止

```dart
// 硬编码颜色
final textColor = isDark ? const Color(0xFFDCE0E5) : const Color(0xFF242529);
Container(color: const Color(0xFF282C33))
Colors.black26
Colors.transparent  // ✅ 例外：transparent 是语义化的，允许
```

### ✅ 正确

```dart
final custom = CustomTheme.of(context);

// 使用语义化颜色 token
final textColor = custom.colors.textPrimary;
final bgColor = custom.colors.panel;
Container(color: custom.colors.background)

// 在 AppText / AppIcon 中设置颜色
AppText('Hello', color: custom.colors.textSecondary)
AppIcon('settings', color: custom.colors.accent)
```

### 可用颜色角色

```dart
AppColorRole.background       // 背景
AppColorRole.panel             // 面板
AppColorRole.panelElevated     // 浮起面板
AppColorRole.hover             // 悬停
AppColorRole.selected          // 选中
AppColorRole.textPrimary       // 主文本
AppColorRole.textSecondary     // 次文本
AppColorRole.textDisabled      // 禁用文本
AppColorRole.accent            // 强调色
AppColorRole.onAccent          // 强调色上的文本
AppColorRole.accentHover       // 强调色悬停
AppColorRole.danger            // 危险
AppColorRole.onDanger          // 危险色上的文本
AppColorRole.border            // 边框
AppColorRole.borderSubtle      // 弱边框
AppColorRole.overlay           // 遮罩
AppColorRole.menuBackground    // 菜单背景
AppColorRole.menuBorder        // 菜单边框
AppColorRole.menuHover         // 菜单悬停
AppColorRole.cardBackground    // 卡片背景
AppColorRole.cardBorder        // 卡片边框
AppColorRole.success           // 成功
AppColorRole.warning           // 警告
```

> **注意**：`Colors.transparent` 是 Flutter 内置的语义化颜色，允许在需要透明背景的地方使用。

## 7. 间距与尺寸规范

禁止在 `EdgeInsets`、`SizedBox`、`Container(width/height)` 等处使用原始数字魔法值。

### ❌ 禁止

```dart
const EdgeInsets.all(24)
const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
SizedBox(height: 8)
Container(width: 48, height: 48)
SizedBox(width: 12)
padding: EdgeInsets.only(top: 8, left: 16)
```

### ✅ 正确

```dart
final custom = CustomTheme.of(context);

// 间距
EdgeInsets.all(custom.spacing.lg)                          // 24
EdgeInsets.symmetric(horizontal: custom.spacing.md)         // 16
EdgeInsets.symmetric(horizontal: custom.spacing.sm)         // 8
SizedBox(height: custom.spacing.sm)                         // 8
padding: EdgeInsets.only(
  top: custom.spacing.sm,                                   // 8
  left: custom.spacing.md,                                  // 16
)

// 尺寸
Container(width: custom.controls.mediumHeight)              // 32

// 圆角
BorderRadius.circular(4) → custom.radii.xs
BorderRadius.circular(8) → custom.radii.sm
BorderRadius.circular(12) → custom.radii.md

// 高度
SizedBox(height: custom.controls.smallHeight)               // 24
SizedBox(height: custom.controls.mediumHeight)              // 32
SizedBox(height: custom.controls.largeHeight)               // 40
```

### 间距速查表

| Token | 值 | 使用场景 |
|-------|-----|---------|
| `custom.spacing.xs` | 4 | 紧凑间距、小元素间距、内边距 |
| `custom.spacing.sm` | 8 | 元素间间距、按钮内边距 |
| `custom.spacing.md` | 16 | 容器内边距、区块间距 |
| `custom.spacing.lg` | 24 | 大区块间距、页面边距 |
| `custom.spacing.xl` | 32 | 超大间距、分组间距 |

## 8. 文本变体规范

所有文本必须使用 `AppTextVariant` 控制大小与字重，禁止在 `AppText` 的 `style` 参数中直接设置 `fontSize`。

### ❌ 禁止

```dart
AppText(label, style: TextStyle(fontSize: 9))
AppText('标题', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))
```

### ✅ 正确

```dart
AppText('小字标注', variant: AppTextVariant.caption)
AppText('正文内容', variant: AppTextVariant.body)
AppText('小标题', variant: AppTextVariant.subtitle)
AppText('标题', variant: AppTextVariant.title)
AppText('二级标题', variant: AppTextVariant.h2)
AppText('一级标题', variant: AppTextVariant.h1)
```

### 变体对照表

| Variant | 字号 | 字重 | 使用场景 |
|---------|------|------|----------|
| `caption` | 12 | `bodyWeight` (默认 w400) | 标注、辅助文字、快捷键提示 |
| `body` | 14 | `bodyWeight` (默认 w400) | 正文、列表项、按钮文字 |
| `subtitle` | 16 | w500 | 小标题、卡片标题 |
| `title` | 18 | w600 | 区块标题、弹窗标题 |
| `h2` | 24 | w600 | 二级页面标题 |
| `h1` | 32 | w600 | 一级页面标题 |

> **例外**：非字体大小的样式（如 `color`、`letterSpacing`、`height`）可以通过 `style` 参数覆盖，但不应包含 `fontSize`。

```dart
// ✅ 允许：只覆盖颜色和字距，不覆盖字号
AppText('LABEL',
  variant: AppTextVariant.caption,
  style: TextStyle(
    color: custom.colors.textSecondary,
    letterSpacing: 0.5,
  ),
)
```

## 9. 路由管理规范

### 9.1 路径常量

所有路由路径在 `AppRoutes` 抽象类中定义为静态常量，禁止在路由表中直接写字符串路径。

```dart
abstract class AppRoutes {
  static const chat = '/';
  static const demo = '/demo';
  static const settings = '/settings';
}
```

### 9.2 ShellRoute 统一布局

使用 `go_router` 的 `ShellRoute` 实现统一布局，避免在每个页面重复写布局代码。

```dart
final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.demo,
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainLayout(child: child),
      routes: [
        GoRoute(path: AppRoutes.chat, builder: (_, __) => const ChatPage()),
        GoRoute(path: AppRoutes.demo, builder: (_, __) => const DemoPage()),
        GoRoute(path: AppRoutes.settings, builder: (_, __) => const SettingsPage()),
      ],
    ),
  ],
);
```

## 10. Provider 规范

### 10.1 @riverpod 注解

所有 Riverpod provider 必须使用 `@riverpod` 注解配合 `riverpod_generator`，通过 `build_runner` 生成 `.g.dart` 文件。

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'my_provider.g.dart';

@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  int build() => 0;

  void update(int value) => state = value;
}

@riverpod
String greeting(Ref ref) {
  final count = ref.watch(myNotifierProvider);
  return 'Count: $count';
}
```

### 10.2 Provider 分类

| 类型 | 注解 | 使用场景 |
|------|------|----------|
| 可变状态 (class) | `@riverpod class X extends _$X` | 需要方法的复杂状态（ThemeNotifier） |
| 派生/computed | `@riverpod X(Ref ref)` | 从其他 provider 派生的只读值 |
| 异步 | `@riverpod Future<T> X(Ref ref)` | 异步数据获取 |
| Stream | `@riverpod Stream<T> X(Ref ref)` | 流式数据 |

### 10.3 命名约定

自动生成的 provider 命名规则：

| 注解方法名 | 生成的 provider |
|-----------|----------------|
| `@riverpod class ThemeNotifier` | `themeNotifierProvider` |
| `@riverpod Brightness effectiveBrightness(Ref ref)` | `effectiveBrightnessProvider` |

### 10.4 在 Widget 中使用

```dart
// 监听
final value = ref.watch(myProvider);
final value = ref.watch(myNotifierProvider);

// 读取一次
final value = ref.read(myProvider);

// 调用方法修改状态
ref.read(myNotifierProvider.notifier).update(42);
```
