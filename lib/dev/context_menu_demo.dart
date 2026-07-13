import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/context_menu/context_menu.dart';
import 'package:agent/widgets/text/app_text.dart';

/// A demo section that showcases the Zed-style context menu.
class ContextMenuDemo extends HookWidget {
  const ContextMenuDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final feedback = useState<String?>(null);

    final textColor = isDark
        ? const Color(0xFFDCE0E5)
        : const Color(0xFF242529);
    final mutedColor = isDark
        ? const Color(0xFFA9AFBC)
        : const Color(0xFF58585A);
    final bgColor = isDark ? const Color(0xFF282C33) : const Color(0xFFFAFAFA);
    final borderColor = isDark
        ? const Color(0xFF464B57)
        : const Color(0xFFC9C9CA);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──
          AppText('Zed 右键菜单', variant: AppTextVariant.title, color: textColor),
          const SizedBox(height: 4),
          AppText(
            '右键或长按任意区域，体验 Zed IDE 风格的上下文菜单',
            variant: AppTextVariant.caption,
            color: mutedColor,
          ),
          const SizedBox(height: 20),

          // ── Feedback toast ──
          if (feedback.value != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2F343E)
                    : const Color(0xFFEBEBEC),
                borderRadius: BorderRadius.circular(6),
              ),
              child: AppText('选中: ${feedback.value}', color: textColor),
            ),

          // ── 示例1: 编辑器右键菜单 ──
          _SectionLabel(text: '编辑器上下文菜单', textColor: textColor),
          const SizedBox(height: 8),
          MenuArea(
            builder: (ctx) => [
              MenuItem(
                label: 'Go to Definition',
                shortcut: 'F12',
                icon: 'arrowRight',
                onTap: () => feedback.value = 'Go to Definition',
              ),
              MenuItem(
                label: 'Go to Declaration',
                shortcut: '\u2325F12',
                icon: 'arrowUpRight',
                onTap: () => feedback.value = 'Go to Declaration',
              ),
              MenuItem(
                label: 'Find All References',
                shortcut: '\u21E7F12',
                icon: 'search',
                onTap: () => feedback.value = 'Find All References',
              ),
              const MenuItem.separator(),
              MenuItem(
                label: 'Rename Symbol',
                shortcut: 'F2',
                icon: 'pencil',
                onTap: () => feedback.value = 'Rename Symbol',
              ),
              MenuItem(
                label: 'Format Buffer',
                shortcut: '\u21E7\u2325F',
                icon: 'indentIncrease',
                onTap: () => feedback.value = 'Format Buffer',
              ),
              MenuItem(
                label: 'Show Code Actions',
                shortcut: '\u2318.',
                icon: 'lightbulb',
                onTap: () => feedback.value = 'Show Code Actions',
              ),
              const MenuItem.separator(),
              MenuItem(
                label: 'Cut',
                shortcut: '\u2318X',
                icon: 'scissors',
                onTap: () => feedback.value = 'Cut',
              ),
              MenuItem(
                label: 'Copy',
                shortcut: '\u2318C',
                onTap: () => feedback.value = 'Copy',
              ),
              MenuItem(label: 'Paste', shortcut: '\u2318V', enabled: false),
            ],
            child: _MockCodeEditor(
              isDark: isDark,
              custom: custom,
              textColor: textColor,
              bgColor: bgColor,
              borderColor: borderColor,
            ),
          ),
          const SizedBox(height: 28),

          // ── 示例2: 勾选与子菜单 ──
          _SectionLabel(text: '勾选状态 & 子菜单', textColor: textColor),
          const SizedBox(height: 8),
          MenuArea(
            builder: (ctx) => [
              const MenuItem(
                label: 'Word Wrap',
                selected: true,
                icon: 'wrapText',
              ),
              const MenuItem(
                label: 'Show Indent Guides',
                selected: false,
                icon: 'alignJustify',
              ),
              const MenuItem(
                label: 'Show Line Numbers',
                selected: true,
                icon: 'hash',
              ),
              const MenuItem.separator(),
              MenuItem(
                label: 'Syntax Highlighting',
                icon: 'palette',
                submenu: [
                  const MenuItem(label: 'Automatic', selected: true),
                  const MenuItem(label: 'Rust', selected: false),
                  const MenuItem(label: 'Python', selected: false),
                  const MenuItem.separator(),
                  const MenuItem(
                    label: 'Disable',
                    selected: false,
                    enabled: false,
                  ),
                ],
              ),
              MenuItem(
                label: 'Encoding',
                icon: 'fileCode',
                submenu: [
                  const MenuItem(label: 'UTF-8', selected: true),
                  const MenuItem(label: 'UTF-16', selected: false),
                  const MenuItem(label: 'ISO-8859-1', selected: false),
                ],
              ),
            ],
            child: _DemoCard(
              isDark: isDark,
              bgColor: bgColor,
              borderColor: borderColor,
              textColor: mutedColor,
              custom: custom,
              message: '右键点击此卡片测试勾选和子菜单',
            ),
          ),
          const SizedBox(height: 28),

          // ── 示例3: 项目管理器 ──
          _SectionLabel(text: '项目面板上下文菜单', textColor: textColor),
          const SizedBox(height: 8),
          MenuArea(
            builder: (ctx) => [
              const MenuItem(label: 'New File', icon: 'filePlus'),
              const MenuItem(label: 'New Folder', icon: 'folderPlus'),
              const MenuItem.separator(),
              const MenuItem(
                label: 'Cut',
                shortcut: '\u2318X',
                icon: 'scissors',
              ),
              const MenuItem(label: 'Copy', shortcut: '\u2318C'),
              const MenuItem(label: 'Paste', shortcut: '\u2318V'),
              const MenuItem.separator(),
              const MenuItem(label: 'Rename', icon: 'pencil'),
              const MenuItem(label: 'Delete', icon: 'trash2', enabled: false),
              const MenuItem.separator(),
              MenuItem(
                label: 'Reveal in File Manager',
                icon: 'folderOpen',
                onTap: () => feedback.value = 'Reveal in File Manager',
              ),
              MenuItem(
                label: 'Open in Terminal',
                icon: 'terminal',
                onTap: () => feedback.value = 'Open in Terminal',
              ),
            ],
            child: _DemoCard(
              isDark: isDark,
              bgColor: bgColor,
              borderColor: borderColor,
              textColor: mutedColor,
              custom: custom,
              message: '右键点击此卡片测试项目面板菜单',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ──
class _SectionLabel extends StatelessWidget {
  final String text;
  final Color textColor;
  const _SectionLabel({required this.text, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return AppText(text, variant: AppTextVariant.body, color: textColor);
  }
}

// ── Mock code editor ──
class _MockCodeEditor extends StatelessWidget {
  final bool isDark;
  final CustomTheme custom;
  final Color textColor, bgColor, borderColor;

  const _MockCodeEditor({
    required this.isDark,
    required this.custom,
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final gutterColor = isDark
        ? const Color(0xFF2F343E)
        : const Color(0xFFEBEBEC);
    final lineNumColor = isDark
        ? const Color(0xFF4E5A5F)
        : const Color(0xFFB4B4BB);

    const lines = [
      'fn fibonacci(n: u32) -> u32 {',
      '    match n {',
      '        0 => 0,',
      '        1 => 1,',
      '        _ => fibonacci(n - 1) + fibonacci(n - 2),',
      '    }',
      '}',
      '',
      'fn main() {',
      '    let result = fibonacci(10);',
      '    println!("Result: {}", result);',
      '}',
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: custom.radii.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gutter
          Container(
            width: 48,
            color: gutterColor,
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(lines.length, (i) {
                return SizedBox(
                  height: 22,
                  child: AppText(
                    '${i + 1}',
                    style: TextStyle(fontSize: 12, color: lineNumColor),
                  ),
                );
              }),
            ),
          ),
          // Code
          Expanded(
            child: Container(
              color: bgColor,
              padding: const EdgeInsets.only(top: 8, left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines.map((line) {
                  return SizedBox(
                    height: 22,
                    child: AppText(
                      line,
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor,
                        height: 1.2,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Demo card ──
class _DemoCard extends StatelessWidget {
  final bool isDark;
  final Color bgColor, borderColor, textColor;
  final CustomTheme custom;
  final String message;

  const _DemoCard({
    required this.isDark,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.custom,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: custom.radii.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.mousePointer2, size: 16, color: textColor),
          const SizedBox(width: 8),
          AppText(message, color: textColor),
        ],
      ),
    );
  }
}
