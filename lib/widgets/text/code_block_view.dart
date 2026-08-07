import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart' as hl_c;
import 'package:re_highlight/languages/clojure.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/diff.dart';
import 'package:re_highlight/languages/dockerfile.dart';
import 'package:re_highlight/languages/elixir.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/haskell.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/lua.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/plaintext.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/text/highlight_text.dart';

/// 代码块 — VSCode 风格深色渲染（背景 + 语法高亮 + 复制按钮）。
///
/// 高亮引擎用 re_highlight（与项目其他代码高亮一致，`highlightToSpan`
/// 的文本 span 直接携带 scope 样式，无 flutter_highlight 的样式丢失
/// 问题）；容器固定 Atom One Dark 深色主题（#282C34），不随 app
/// 亮暗切换，聊天场景保持经典深色代码块观感。整段可选中复制，
/// 长行横向滚动。
class CodeBlockView extends StatelessWidget {
  /// 代码内容（可为流式更新中的半截文本）
  final String code;

  /// 语言语法定义，如 `package:re_highlight/languages/diff.dart` 的 `langDiff`
  final Mode language;

  /// 头部语言标签；默认取 [language.name] 小写
  final String? label;

  /// 高亮主题：scope 名 → 文字样式；默认 Atom One Dark
  final Map<String, TextStyle>? theme;

  const CodeBlockView({
    super.key,
    required this.code,
    required this.language,
    this.label,
    this.theme,
  });

  static const _radius = 8.0;
  static const _borderColor = Color(0xFF3E4451);
  static const _lineHeight = 18.0;
  static const _contentFontSize = 12.0;

  /// markdown fence 语言名 → re_highlight 语法（含常见别名）
  static final Map<String, Mode> fenceLanguages = {
    'diff': langDiff,
    'patch': langDiff,
    'dart': langDart,
    'python': langPython,
    'py': langPython,
    'javascript': langJavascript,
    'js': langJavascript,
    'jsx': langJavascript,
    'typescript': langTypescript,
    'ts': langTypescript,
    'json': langJson,
    'rust': langRust,
    'rs': langRust,
    'bash': langBash,
    'sh': langBash,
    'shell': langBash,
    'zsh': langBash,
    'c': hl_c.langC,
    'cpp': langCpp,
    'c++': langCpp,
    'csharp': langCsharp,
    'cs': langCsharp,
    'go': langGo,
    'java': langJava,
    'kotlin': langKotlin,
    'swift': langSwift,
    'sql': langSql,
    'yaml': langYaml,
    'yml': langYaml,
    'xml': langXml,
    'html': langXml,
    'markdown': langMarkdown,
    'md': langMarkdown,
    'css': langCss,
    'php': langPhp,
    'ruby': langRuby,
    'lua': langLua,
    'elixir': langElixir,
    'haskell': langHaskell,
    'clojure': langClojure,
    'dockerfile': langDockerfile,
    'docker': langDockerfile,
    'text': langPlaintext,
    'plaintext': langPlaintext,
    'txt': langPlaintext,
  };

  /// 按 markdown fence 语言名查找语法；未知语言回退纯文本
  static Mode modeForFence(String? name) {
    if (name == null) return langPlaintext;
    return fenceLanguages[name.toLowerCase()] ?? langPlaintext;
  }

  @override
  Widget build(BuildContext context) {
    if (code.isEmpty) {
      return const SizedBox.shrink();
    }

    final resolvedTheme = theme ?? atomOneDarkTheme;
    final root = resolvedTheme['root'];
    final background = root?.backgroundColor ?? const Color(0xFF282C34);
    final foreground = root?.color ?? const Color(0xFFABB2BF);
    final custom = CustomTheme.of(context);
    final base = TextStyle(
      // 代码块字体直接跟随主题设置（默认 JetBrainsMono），字号随全局缩放
      fontFamily: custom.typography.fontFamily ?? kDefaultFontFamily,
      fontSize: _contentFontSize * custom.typography.fontSizeScale,
      height: _lineHeight / _contentFontSize,
      color: foreground,
    );
    final span = highlightToSpan(
      code: code,
      language: language,
      baseStyle: base,
      theme: resolvedTheme,
    );

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CodeBlockHeader(
            label: label ?? language.name?.toLowerCase(),
            code: code,
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: SelectableText.rich(span, style: base),
          ),
        ],
      ),
    );
  }
}

/// 代码块头部：语言标签 + 一键复制按钮
class CodeBlockHeader extends StatelessWidget {
  const CodeBlockHeader({super.key, required this.label, required this.code});

  /// 语言标签文字
  final String? label;

  /// 复制按钮复制的内容（整段代码/补丁）
  final String code;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
      child: Row(
        children: [
          if (label != null && label!.isNotEmpty)
            Text(
              label!,
              style: TextStyle(
                color: _CodeBlockViewColors.headerForeground,
                // 字体跟随主题设置（默认 JetBrainsMono），字号随全局缩放
                fontFamily:
                    CustomTheme.of(context).typography.fontFamily ??
                    kDefaultFontFamily,
                fontSize: 11 * CustomTheme.of(context).typography.fontSizeScale,
              ),
            ),
          const Spacer(),
          _CopyButton(code: code),
        ],
      ),
    );
  }
}

/// 代码块内部的固定前景色（头部标签/复制按钮）
abstract final class _CodeBlockViewColors {
  static const headerForeground = Color(0xFF8A919E);
}

/// 复制到剪贴板按钮：点击后短暂显示对勾
class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.code});

  final String code;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;
  Timer? _resetTimer;

  Future<void> _onTap() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _copied ? 'Copied' : 'Copy',
      onPressed: widget.code.isEmpty ? null : _onTap,
      icon: Icon(
        _copied ? Icons.check : Icons.content_copy_outlined,
        size: 16,
        color: _CodeBlockViewColors.headerForeground,
      ),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
