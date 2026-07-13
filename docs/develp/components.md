# 公共组件库概览

## 概述

公共组件位于 `lib/widgets/<type>/` 目录下，每个组件类型一个子目录。所有组件均使用 `CustomTheme` 主题 token，遵循"组件优先"原则——能用组件的地方必须用组件。

```
lib/widgets/
├── text/            AppText — 所有文本
├── icon/            AppIcon — 所有图标
├── button/          AppButton — 所有按钮
├── card/            AppCard — 卡片容器
├── divider/         AppDivider — 分隔线
├── list/            AppList / AppListItem — 列表
└── context_menu/    MenuItem / ContextMenu / MenuArea — 右键菜单
```

---

## 1. AppText — 文本

**文件**：`lib/widgets/text/app_text.dart`

所有文本必须使用 `AppText`，禁止直接使用 `Text`。

### Props

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `data` | `String` | - | 文本内容（必填） |
| `variant` | `AppTextVariant` | `body` | 文本变体，控制字号和字重 |
| `color` | `Color?` | `textPrimary` | 文本颜色 |
| `style` | `TextStyle?` | - | 额外样式覆盖（不应包含 fontSize） |
| `textAlign` | `TextAlign?` | - | 对齐方式 |
| `overflow` | `TextOverflow?` | - | 溢出处理 |
| `maxLines` | `int?` | - | 最大行数 |

### AppTextVariant 对照

| Variant | 字号 | 字重 | 用途 |
|---------|------|------|------|
| `caption` | 12 | bodyWeight | 标注、辅助文字、快捷键提示 |
| `body` | 14 | bodyWeight | 正文、列表项、按钮文字 |
| `subtitle` | 16 | w500 | 小标题、卡片标题 |
| `title` | 18 | w600 | 区块标题、弹窗标题 |
| `h2` | 24 | w600 | 二级页面标题 |
| `h1` | 32 | w600 | 一级页面标题 |

### 用法

```dart
// 基础
AppText('Hello World')

// 指定变体
AppText('标题', variant: AppTextVariant.title)

// 指定颜色
AppText('次要信息', color: custom.colors.textSecondary)

// 带额外样式（仅覆盖非字号属性）
AppText('LABEL',
  variant: AppTextVariant.caption,
  style: TextStyle(letterSpacing: 0.5),
)
```

---

## 2. AppIcon — 图标

**文件**：`lib/widgets/icon/app_icon.dart`

所有图标必须使用 `AppIcon`，通过名称注册表查找对应的 Lucide 图标。禁止直接使用 `Icon` 或 `LucideIcons.xxx`。

### 图标注册表

`AppIcon` 内部维护 `_registry`，通过名称字符串查找图标。名称 + `iconThickness`（0-600）决定具体使用的 Lucide 图标变体。

```dart
AppIcon('settings')        // 厚度 300（默认）
AppIcon('settings', size: 18)
```

### 已注册图标

| 名称 | 支持厚度变体 | 说明 |
|------|-------------|------|
| `sun` | 0-600 | 太阳（亮色模式） |
| `moon` | 0-600 | 月亮（暗色模式） |
| `brush` | 0-600 | 画笔（主题编辑） |
| `settings` | 0-600 | 设置 |
| `refresh` | 0-600 | 刷新 |
| `trash` | 0-600 | 删除 |
| `square` | 0-600 | 方块 |
| `terminal` | 0-600 | 终端 |
| `terminalSquare` | 0-600 | 终端方块 |
| `activity` | 0-600 | 活动 |
| `x` | 0-600 | 关闭 |
| `plus` | 0-600 | 添加 |
| `arrowRight` | 0 | 右箭头 |
| `arrowUpRight` | 0 | 右上箭头 |
| `search` | 0 | 搜索 |
| `pencil` | 0 | 编辑 |
| `indentIncrease` | 0 | 缩进 |
| `lightbulb` | 0 | 代码操作 |
| `scissors` | 0 | 剪切 |
| `copy` | 0 | 复制 |
| `wrapText` | 0 | 自动换行 |
| `alignJustify` | 0 | 对齐 |
| `hash` | 0 | 行号 |
| `palette` | 0 | 调色板 |
| `fileCode` | 0 | 代码文件 |
| `filePlus` | 0 | 新建文件 |
| `folderPlus` | 0 | 新建文件夹 |
| `trash2` | 0 | 删除（菜单） |
| `folderOpen` | 0 | 打开文件夹 |
| `clipboardPaste` | 0 | 粘贴 |
| `clipboardType` | 0 | 粘贴文字 |
| `delete` | 0 | 删除 |
| `checkSquare2` | 0 | 全选 |
| `eraser` | 0 | 清除 |

### Props

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `name` | `String` | - | 图标注册名称（必填） |
| `size` | `double?` | - | 图标尺寸 |
| `color` | `Color?` | `textPrimary` | 图标颜色 |

### 用法

```dart
AppIcon('terminal')
AppIcon('settings', size: 18)
AppIcon('sun', color: custom.colors.accent)
```

### 添加新图标

1. 在 `_registry` 中添加名称到 `IconData` 的映射
2. 如果 Lucide 图标有 thickness 变体，注册 0-600 共 7 档；如果没有，仅注册 `0` 即可

```dart
'myIcon': {
  0: LucideIcons.myIcon,
  100: LucideIcons.myIcon100,
  // ... 直到 600
},
// 或
'mySimpleIcon': {0: LucideIcons.mySimpleIcon},
```

---

## 3. AppButton — 按钮

**文件**：`lib/widgets/button/app_button.dart`

### Variant

| 变体 | 用途 | 外观 |
|------|------|------|
| `primary` | 主要操作 | 填充 accent 色背景 |
| `secondary` | 次要操作 | 透明背景 + 弱边框 |
| `text` | 文字按钮 | 纯文字，hover 显示强调色 |
| `iconOnly` | 纯图标按钮 | 方形图标按钮，hover 显示背景 |

### Size

| 尺寸 | 高度 | 圆角 | 图标大小 |
|------|------|------|---------|
| `sm` | 24 | xs (4) | caption (12) |
| `md` | 32 | xs (4) | subtitle (16) |
| `lg` | 40 | sm (8) | title (18) |

### Props

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `text` | `String?` | - | 按钮文字（`iconOnly` 时作为 Tooltip） |
| `icon` | `String?` | - | 图标名称 |
| `onPressed` | `VoidCallback?` | - | 点击回调（null 时按钮禁用） |
| `variant` | `ButtonVariant` | `primary` | 按钮变体 |
| `size` | `ButtonSize` | `md` | 按钮尺寸 |
| `disabled` | `bool` | `false` | 强制禁用 |
| `hoverStyle` | `bool` | `true` | 是否显示悬停态样式 |
| `style` | `ButtonStyle?` | - | 额外样式覆盖 |

### 用法

```dart
// 主要按钮
AppButton(text: '确定', onPressed: () {})

// 次要按钮
AppButton(text: '取消', variant: ButtonVariant.secondary, onPressed: () {})

// 文字按钮
AppButton(text: '重置', variant: ButtonVariant.text, onPressed: () {})

// 纯图标
AppButton(icon: 'settings', variant: ButtonVariant.iconOnly, onPressed: () {})

// 图标 + 文字
AppButton(icon: 'terminal', text: '打开终端', onPressed: () {})

// 小尺寸
AppButton(text: '小', size: ButtonSize.sm, onPressed: () {})

// 禁用
AppButton(text: '不可用', onPressed: disabled ? null : () {})
```

---

## 4. AppCard — 卡片容器

**文件**：`lib/widgets/card/app_card.dart`

主题驱动的卡片容器，支持自定义背景、边框、圆角、阴影以及滚动约束。

### Props

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `child` | `Widget` | - | 子组件（必填） |
| `minWidth` | `double?` | - | 最小宽度 |
| `maxHeight` | `double?` | - | 最大高度（超出可滚动） |
| `stepWidth` | `double?` | - | IntrinsicWidth stepWidth |
| `padding` | `EdgeInsetsGeometry?` | `spacing.xs` | 内边距 |
| `backgroundColor` | `Color?` | `cardBackground` | 背景色 |
| `borderRadius` | `BorderRadius?` | `radii.sm` | 圆角 |
| `border` | `Border?` | `cardBorder` 1px solid | 边框 |
| `boxShadow` | `List<BoxShadow>?` | `shadows.small` | 阴影 |
| `scrollable` | `bool` | `true` | 内容超出 maxHeight 时是否可滚动 |

### 用法

```dart
// 默认卡片
AppCard(
  child: Column(
    children: [
      AppText('标题', variant: AppTextVariant.subtitle),
      AppText('内容'),
    ],
  ),
)

// 菜单面板
AppCard(
  minWidth: 160,
  backgroundColor: custom.colors.menuBackground,
  border: Border.all(color: custom.colors.menuBorder),
  child: ...,
)

// 固定尺寸、不可滚动
AppCard(
  maxHeight: 300,
  scrollable: false,
  child: ...,
)
```

### 默认主题映射

```dart
backgroundColor → custom.colors.cardBackground
borderRadius    → custom.radii.sm
border          → Border.all(color: custom.colors.cardBorder, width: 1)
boxShadow       → custom.shadows.small
padding         → EdgeInsets.all(custom.spacing.xs)
```

---

## 5. AppDivider — 分隔线

**文件**：`lib/widgets/divider/app_divider.dart`

### Props

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `axis` | `Axis` | `horizontal` | 方向 |
| `thickness` | `double` | 1.0 | 线宽 |
| `extent` | `double?` | `spacing.sm` | 容器尺寸（水平时高度，垂直时宽度） |
| `indent` | `double?` | 0 | 前导空白 |
| `endIndent` | `double?` | 0 | 尾部空白 |
| `color` | `Color?` | `border` | 颜色 |

### 用法

```dart
// 水平分隔线（菜单中）
AppDivider()

// 垂直分隔线（工具栏中）
AppDivider(axis: Axis.vertical)

// 带缩进
AppDivider(indent: custom.spacing.xs, endIndent: custom.spacing.xs)
```

---

## 6. AppList / AppListItem — 列表

**文件**：`lib/widgets/list/app_list.dart`

### AppList（列表容器）

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `children` | `List<Widget>` | - | 子组件 |
| `width` | `double?` | - | 宽度 |
| `containerPadding` | `EdgeInsetsGeometry?` | `spacingSm` | 容器内边距 |
| `itemGap` | `double?` | `spacingXs` | 子组件间距 |
| `containerRadius` | `BorderRadiusGeometry?` | `radiusSm` | 容器圆角 |
| `containerColor` | `Color?` | `transparent` | 容器背景 |

### AppListItem（列表项）

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `icon` | `String?` | - | 图标名称 |
| `label` | `String` | - | 主文本（必填） |
| `trailing` | `String?` | - | 尾部文字（如快捷键） |
| `active` | `bool` | `false` | 选中态 |
| `disabled` | `bool` | `false` | 禁用态 |
| `onTap` | `VoidCallback?` | - | 点击回调 |
| `trailingWidget` | `Widget?` | - | 尾部组件（如子菜单箭头） |
| `labelVariant` | `AppTextVariant?` | `body` | 文本变体 |
| `intrinsicHeight` | `bool` | `false` | 高度由内容撑开而非固定高度 |
| `onHover` | `Function(bool, RenderBox)?` | - | hover 状态回调 |
| `itemHeight` | `double?` | `controls.mediumHeight` | 固定高度 |
| `itemPadding` | `EdgeInsetsGeometry?` | 左右 `spacing.sm` | 内边距 |
| `itemRadius` | `BorderRadiusGeometry?` | `radii.sm` | 圆角 |
| `iconSize` | `double?` | `typography.titleSize` | 图标尺寸 |
| `iconLabelGap` | `double?` | `spacing.sm` | 图标与文字间距 |

### 用法

```dart
// 基础列表
AppList(
  children: [
    AppListItem(icon: 'terminal', label: '终端', onTap: () {}),
    AppListItem(icon: 'settings', label: '设置', onTap: () {}),
  ],
)

// 选中态 + 快捷键
AppListItem(
  icon: 'wrapText',
  label: '自动换行',
  active: true,
  trailing: 'Ctrl+Shift+W',
)

// 自适应高度 + hover 回调
AppListItem(
  icon: 'folderOpen',
  label: '打开文件夹',
  intrinsicHeight: true,
  onHover: (isHovered, box) { /* ... */ },
)
```

### 交互状态

| 状态 | 背景色 |
|------|--------|
| 默认 | `transparent` |
| hover（enabled） | `custom.colors.hover` |
| pressed（enabled） | `custom.colors.selected` |
| active | `custom.colors.selected` |
| disabled | 鼠标指针变为 `basic` |

---

## 7. ContextMenu — 上下文菜单

**文件**：`lib/widgets/context_menu/context_menu.dart`

### MenuItem（数据模型）

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `label` | `String` | - | 菜单项文字 |
| `icon` | `String?` | - | 图标名称 |
| `shortcut` | `String?` | - | 快捷键提示 |
| `enabled` | `bool` | `true` | 是否可用 |
| `selected` | `bool` | `false` | 是否选中（勾选态） |
| `submenu` | `List<MenuItem>?` | - | 子菜单项 |
| `onTap` | `VoidCallback?` | - | 点击回调 |
| `MenuItem.separator()` | - | - | 分隔线 |

### ContextMenu（全局管理）

```dart
// 显示
ContextMenu.show(
  context,
  position: event.position,
  items: [/* ... */],
);

// 关闭
ContextMenu.dismiss();
```

### MenuArea（便捷包装器）

将任意 child 包装为可右键/长按弹出菜单的区域：

```dart
MenuArea(
  builder: (context) => [
    MenuItem(label: '打开', icon: 'folderOpen', onTap: () {}),
    MenuItem(label: '复制', icon: 'copy', shortcut: 'Ctrl+C'),
    const MenuItem.separator(),
    MenuItem(label: '删除', icon: 'trash2', enabled: false),
  ],
  child: MyContent(),
)
```

### 子菜单机制

子菜单使用 `OverlayEntry` + `Timer` 实现：

| 动作 | 延迟 | 行为 |
|------|------|------|
| hover 到有子菜单的项 | 300ms | 打开子菜单 |
| 移出父菜单项（子菜单未 hover） | 200ms | 关闭子菜单 |
| hover 到子菜单上 | 立即 | 取消关闭计时器 |
| 点击子菜单项 | - | 关闭所有菜单并执行回调 |

```dart
MenuItem(
  label: '语法高亮',
  icon: 'palette',
  submenu: [
    const MenuItem(label: '自动', selected: true),
    const MenuItem(label: 'Rust'),
    const MenuItem(label: 'Python'),
  ],
)
```

---

## 8. 组件选型速查表

当你需要实现某个 UI 时，参考下表找到正确的组件：

| 你需要 | 使用 | 禁止 |
|--------|------|------|
| 显示一段文字 | `AppText` | `Text` |
| 显示一个图标 | `AppIcon` | `Icon`、`LucideIcons.xxx` |
| 一个可点击的按钮 | `AppButton` | `TextButton`、`ElevatedButton`、`IconButton` |
| 一个浮动操作按钮 | `AppButton(icon: 'plus', variant: .iconOnly)` | `FloatingActionButton` |
| 一个有背景/边框/阴影的容器 | `AppCard` | `Container` + 手动 `BoxDecoration` |
| 一条横线或竖线分隔 | `AppDivider` | `Divider`、`VerticalDivider` |
| 一个列表项 | `AppListItem` | `ListTile`、手动 `Row` + `InkWell` |
| 一个列表容器 | `AppList` | 手动 `Column` + `for` 循环 |
| 右键弹出菜单 | `MenuArea` `ContextMenu` | 手写 `OverlayEntry` |
| 弹窗 | `Dialog` + `AppCard` 样式 | 原生 Material `Dialog` |
| 下拉面板 | `AppCard`（菜单样式） | 原生 `PopupMenuButton` |
