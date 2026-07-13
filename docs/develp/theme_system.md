# 主题系统指南

## 概述

主题系统是应用的样式基础设施，所有颜色、间距、圆角、阴影、字号、控件尺寸都通过统一的 token 体系管理。系统支持亮/暗双模式、运行时颜色覆盖、图标粗细调节、正文字重调节等功能。

```
用户操作（设置面板）
     │
     ▼
ThemeSettings（持久化状态）
     │
     ▼
CustomTheme.resolve()（合并 overrides）
     │
     ▼
CustomTheme（作为 ThemeExtension 注入 Material ThemeData）
     │
     ▼
组件通过 CustomTheme.of(context) 消费
```

---

## 文件结构

```
lib/theme/
├── app_colors.dart       # AppColorRole 枚举 + AppColors 类（亮暗各 24 色）
├── app_tokens.dart       # AppSpacing / AppRadii / AppControls / AppTypography / AppShadows
├── custom_theme.dart     # CustomTheme（ThemeExtension，含兼容别名 + 标准别名映射）
├── theme_settings.dart   # ThemeSettings（用户可持久化的设置项）
├── provider.dart         # ThemeNotifier（@riverpod）+ 辅助 provider
└── app_theme.dart        # _buildTheme() 组装 ThemeData
```

---

## 1. AppColors — 颜色系统

### AppColorRole 枚举

24 种语义色角色，每个角色代表一种**用途**而非具体颜色值：

| 类别 | 角色 | 用途 |
|------|------|------|
| 背景层 | `background` | 最底层页面背景 |
| | `panel` | 面板背景 |
| | `panelElevated` | 浮起面板（如标签栏背景） |
| | `hover` | 悬停态背景 |
| | `selected` | 选中态背景 |
| 文本 | `textPrimary` | 主文本 |
| | `textSecondary` | 次要文本 |
| | `textDisabled` | 禁用文本 |
| 强调色 | `accent` | 强调色（按钮/滑块主色） |
| | `onAccent` | 强调色上的文本 |
| | `accentHover` | 强调色悬停态 |
| 状态色 | `danger` | 危险/错误 |
| | `onDanger` | 危险色上的文本 |
| | `success` | 成功 |
| | `warning` | 警告 |
| 边框 | `border` | 默认边框 |
| | `borderSubtle` | 弱边框 |
| 浮层 | `overlay` | 遮罩层 |
| | `shadow` | 阴影色 |
| 菜单 | `menuBackground` | 菜单/弹出面板背景 |
| | `menuBorder` | 菜单边框 |
| | `menuHover` | 菜单悬停 |
| 卡片 | `cardBackground` | 卡片背景 |
| | `cardBorder` | 卡片边框 |

### 亮暗双色

`AppColors.light` 和 `AppColors.dark` 两套预定义值，遵循相同的语义结构，仅颜色值不同。

**亮色**：浅灰底 + 黑强调
- 背景 `#F9F9F9` → 面板 `#FDFDFD` → 浮起面板 `#EBEBEB`
- 主文本 `#000000`，次文本 `#68686D`
- 强调色 `#000000`，强调文本 `#FFFFFF`

**暗色**：深黑底 + 白强调
- 背景 `#131313` → 面板 `#2D2D2D` → 浮起面板 `#262626`
- 主文本 `#F5F5F7`，次文本 `#A1A1A6`
- 强调色 `#FFFFFF`，强调文本 `#000000`

### 关键 API

```dart
// 根据 role 取色
colors.colorFor(AppColorRole.accent)

// 替换某个角色的颜色（不可变）
colors.withColor(AppColorRole.accent, newColor)

// 批量应用覆盖
colors.apply({AppColorRole.accent: 0xFFFF0000})

// 两套色间插值
AppColors.lerp(light, dark, 0.5)
```

---

## 2. AppTokens — 尺寸 Token

### AppSpacing（间距）

| Token | 值 | 典型用途 |
|-------|-----|---------|
| `spacing.xs` | 4 | 紧凑间距、图标与文字间距 |
| `spacing.sm` | 8 | 元素间间距、按钮水平内边距 |
| `spacing.md` | 16 | 容器内边距、区块间距 |
| `spacing.lg` | 24 | 页面大边距、分组间距 |
| `spacing.xl` | 32 | 超大间距、区域分隔 |

### AppRadii（圆角）

| Token | 值 | 典型用途 |
|-------|-----|---------|
| `radii.xs` | 4 | 小按钮、输入框、菜单项 |
| `radii.sm` | 8 | 卡片、下拉面板、弹窗 |
| `radii.md` | 12 | 大卡片、对话框 |
| `radii.full` | 999 | 圆形、药丸形 |

### AppControls（控件尺寸）

| Token | 值 | 典型用途 |
|-------|-----|---------|
| `controls.smallHeight` | 24 | 小按钮、标签栏 |
| `controls.mediumHeight` | 32 | 默认按钮、列表项高度 |
| `controls.largeHeight` | 40 | 大按钮、搜索栏 |

### AppTypography（排版）

| Token | 值 | Fallback 字重 |
|-------|-----|---------------|
| `typography.captionSize` | 12 | bodyWeight |
| `typography.bodySize` | 14 | bodyWeight |
| `typography.subtitleSize` | 16 | w500 |
| `typography.titleSize` | 18 | w600 |
| `typography.heading2Size` | 24 | w600 |
| `typography.heading1Size` | 32 | w600 |

**字体系列映射**：通过 `fontWeightToFamily()` 函数将字重映射到 JetBrainsMono 字族变体文件：

| FontWeight | 字族文件 |
|------------|---------|
| w100 | JetBrainsMonoThin |
| w200 | JetBrainsMonoExtraLight |
| w300 | JetBrainsMonoLight |
| w400 | JetBrainsMonoRegular |
| w500 | JetBrainsMonoMedium |
| w600 | JetBrainsMonoSemiBold |
| w700 | JetBrainsMonoBold |
| w800 | JetBrainsMonoExtraBold |

### AppShadows（阴影）

三档阴影，亮暗色分别使用不同透明度：

| Token | blurRadius | offset | light alpha | dark alpha |
|-------|------------|--------|-------------|------------|
| `shadows.small` | 4 | (0, 1) | 8% | 20% |
| `shadows.medium` | 8 | (0, 3) | 10% | 25% |
| `shadows.large` | 16 | (0, 6) | 12% | 30% |

---

## 3. CustomTheme — 主题集成

### 3.1 架构定位

`CustomTheme` 是 `ThemeExtension<CustomTheme>` 的子类，通过 Flutter 的 `ThemeData.extensions` 机制注入。

```dart
ThemeData(
  brightness: custom.brightness,
  scaffoldBackgroundColor: custom.colors.background,
  extensions: [custom],  // ← 注入 CustomTheme
)
```

### 3.2 获取主题

```dart
// 在组件中：
final custom = CustomTheme.of(context);

// 使用各种 token：
custom.colors.textPrimary
custom.spacing.md
custom.radii.sm
custom.typography.bodySize
custom.controls.mediumHeight
custom.shadows.small
```

### 3.3 亮暗实例

```dart
CustomTheme.light   // 亮色模式
CustomTheme.dark    // 暗色模式

// 带 overrides 的解析
CustomTheme.resolve(
  Brightness.light,
  colorOverrides: {AppColorRole.accent: 0xFFFF0000},
  fontWeight: FontWeight.w500,
)
```

---

## 4. ThemeSettings — 用户设置

### 可持久化字段

```dart
class ThemeSettings {
  final ThemeMode themeMode;           // system / light / dark
  final String presetId;               // 预设 ID（保留字段）
  final int iconThickness;             // 图标粗细 0-600
  final int fontWeightValue;           // 正文字重 100-900
  final Map<AppColorRole, int> lightOverrides;  // 亮色覆盖
  final Map<AppColorRole, int> darkOverrides;   // 暗色覆盖
}
```

### 与 CustomTheme 的桥接

```dart
// 扩展方法（provider.dart 中）
settings.effectiveLight   // → 应用 lightOverrides 后的亮色 CustomTheme
settings.effectiveDark    // → 应用 darkOverrides 后的暗色 CustomTheme
settings.effectiveFor(brightness)  // → 根据 brightness 返回对应的有效主题
```

---

## 5. ThemeNotifier — 运行时状态管理

`ThemeNotifier` 是一个 `@riverpod` 注解的 Notifier，管理 `ThemeSettings` 的全部变更。

### 核心方法

| 方法 | 用途 |
|------|------|
| `toggle()` | 切换亮/暗模式 |
| `setThemeMode(ThemeMode)` | 设置主题模式 |
| `setIconThickness(int)` | 设置图标粗细（0-600，自动 clamp） |
| `setFontWeight(FontWeight)` | 设置正文字重 |
| `setColor(Brightness, AppColorRole, Color)` | 覆盖指定颜色 |
| `resetColors({Brightness})` | 重置颜色覆盖 |
| `resetAll()` | 恢复所有默认设置 |

### setColor 自动前景色

当覆盖 `accent` 或 `danger` 色时，系统自动计算最佳前景色（`onAccent` / `onDanger`）：

```dart
void setColor(Brightness brightness, AppColorRole role, Color color) {
  // ... 设置 color ...
  if (role == AppColorRole.accent || role == AppColorRole.danger) {
    // 自动计算对比度最高的前景色（黑或白）
    overrides[foregroundRole] = _bestForeground(color).toARGB32();
  }
}
```

算法基于 WCAG 对比度公式：

```dart
static double _contrastRatio(Color a, Color b) {
  final lighter = a.computeLuminance() > b.computeLuminance() ? a : b;
  final darker = identical(lighter, a) ? b : a;
  return (lighter.computeLuminance() + 0.05) /
         (darker.computeLuminance() + 0.05);
}
```

---

## 6. Provider 体系

```
                themeProvider (ThemeNotifier)
                      │
                      ▼
         effectiveBrightnessProvider (派生)
          ↙        |         ↘
    system      light        dark
      │
      ▼
platformBrightnessProvider (PlatformBrightness)
     （监听系统亮暗变化 via WidgetsBindingObserver）
```

### 各 Provider 职责

| Provider | 类型 | 说明 |
|----------|------|------|
| `themeProvider` | `ThemeNotifier` | 可修改的 theme settings |
| `effectiveBrightnessProvider` | 派生 `Brightness` | 根据 `themeMode` 计算当前实际亮度 |
| `platformBrightnessProvider` | `PlatformBrightness` | 监听系统亮度变化（带 `WidgetsBindingObserver`） |

---

## 7. 应用场景示例

### 在组件中使用

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return Container(
      color: custom.colors.background,
      padding: EdgeInsets.all(custom.spacing.md),
      child: Column(
        children: [
          AppText('标题', variant: AppTextVariant.title),
          SizedBox(height: custom.spacing.sm),
          Container(
            padding: EdgeInsets.all(custom.spacing.sm),
            decoration: BoxDecoration(
              color: custom.colors.panel,
              borderRadius: custom.radii.sm,
              border: Border.all(color: custom.colors.border),
              boxShadow: custom.shadows.small,
            ),
            child: AppText('卡片内容'),
          ),
        ],
      ),
    );
  }
}
```

### 切换亮/暗

```dart
ref.read(themeProvider.notifier).toggle();
```

### 修改强调色

```dart
ref.read(themeProvider.notifier).setColor(
  Brightness.light,
  AppColorRole.accent,
  Color(0xFF1E88E5),
);
```

### 重置颜色

```dart
ref.read(themeProvider.notifier).resetColors(brightness: Brightness.light);
ref.read(themeProvider.notifier).resetAll();
```

---

## 8. 扩展主题

### 新增颜色角色

1. 在 `AppColorRole` 枚举中添加新值
2. 在 `AppColors` 中添加对应的 `Color` 字段
3. 更新 `AppColors.light` 和 `AppColors.dark` 的构造函数参数
4. 更新 `colorFor()` / `withColor()` / `apply()` / `lerp()` 方法
5. （可选）在 `CustomTheme` 中添加兼容别名

> **注意**：每个颜色角色必须同时定义亮色和暗色两套值，`withColor()` 和 `lerp()` 中全部 24 个字段都要处理。

### 新增尺寸 Token

1. 在 `AppSpacing` / `AppRadii` / `AppControls` / `AppTypography` 中添加字段
2. 更新对应的 `lerp()` 方法
3. 在 `CustomTheme` 中添加兼容别名（可选）
