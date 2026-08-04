import 'package:flutter/material.dart';

import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart' as hl_c;
import 'package:re_highlight/languages/clojure.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
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
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/theme/syntax_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/highlight_text.dart';

/// Diff 视图 — apply_patch 补丁专用渲染（GitHub/VSCode diff 风格）。
///
/// 隐藏全部补丁语法噪音，只呈现内容变更：
/// - `*** Begin/End Patch`、`@@` hunk 头、`\ No newline` 尾注 → 不渲染
/// - `*** Add/Update/Delete/Move File: path` 文件头 → 不渲染，但用于
///   推断该文件块内容的语法高亮语言
/// - `+内容` / `-内容` → 去掉符号，仅内容 + 绿/红行背景
/// - 上下文行 → 原样显示
///
/// 内容行按所属文件的语言做 token 级语法高亮（关键字/字符串/注释等），
/// 增删行叠加浅绿/浅红背景；行背景与 token 色取自应用设计 token，
/// 跟随亮暗主题。行首为 VSCode 式双列行号（旧 | 新，删除行显示旧行号、
/// 新增行显示新行号，hunk 头重置、文件头归零），行号弱色且不可选中，
/// 选中复制仅包含内容。短行背景铺满内容宽度，长行可横向滚动。
class DiffCodeBlock extends StatelessWidget {
  /// Unified diff 原文（apply_patch 信封格式）
  final String diff;

  const DiffCodeBlock({super.key, required this.diff});

  static const _lineHeight = 18.0;

  /// 文件扩展名 → re_highlight 语法
  static final Map<String, Mode> _extModes = {
    'dart': langDart,
    'rs': langRust,
    'py': langPython,
    'js': langJavascript,
    'mjs': langJavascript,
    'cjs': langJavascript,
    'jsx': langJavascript,
    'ts': langTypescript,
    'tsx': langTypescript,
    'json': langJson,
    'go': langGo,
    'java': langJava,
    'kt': langKotlin,
    'swift': langSwift,
    'c': hl_c.langC,
    'h': hl_c.langC,
    'cpp': langCpp,
    'cc': langCpp,
    'hpp': langCpp,
    'cs': langCsharp,
    'sh': langBash,
    'bash': langBash,
    'zsh': langBash,
    'yaml': langYaml,
    'yml': langYaml,
    'md': langMarkdown,
    'markdown': langMarkdown,
    'html': langXml,
    'htm': langXml,
    'xml': langXml,
    'css': langCss,
    'php': langPhp,
    'rb': langRuby,
    'lua': langLua,
    'ex': langElixir,
    'hs': langHaskell,
    'clj': langClojure,
    'sql': langSql,
    'dockerfile': langDockerfile,
  };

  /// 文件路径 → 语法语言；未知扩展名返回 null（纯文本渲染）
  static Mode? _modeForPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return null;
    final ext = path.substring(dot + 1).toLowerCase();
    // 带点后缀（如 .dart.g.dart）取最后一段即可，未知则尝试整段
    return _extModes[ext] ?? _extModes[path.toLowerCase()];
  }

  @override
  Widget build(BuildContext context) {
    if (diff.isEmpty) {
      return const SizedBox.shrink();
    }

    final custom = CustomTheme.of(context);
    final colors = custom.colors;
    final fontSize = custom.typography.captionSize;
    final base = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: fontSize,
      height: _lineHeight / fontSize,
      color: colors.textPrimary,
    );
    final syntaxTheme = buildSyntaxTheme(colors);
    // 行背景透明度：暗色主题下更浓（与 GitHub 亮/暗 diff 一致）
    final bgAlpha = custom.brightness == Brightness.dark ? 0.15 : 0.08;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 短行背景铺满内容宽度（横向滚动时随内容延伸）
        final contentWidth = constraints.maxWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in _parse(diff))
                switch (line.kind) {
                  DiffLineKind.fileAdd ||
                  DiffLineKind.fileUpdate ||
                  DiffLineKind.fileDelete ||
                  DiffLineKind.fileMove =>
                    _FileHeader(line: line, custom: custom),
                  DiffLineKind.added => _DiffRow(
                    line: line,
                    background: colors.success.withValues(alpha: bgAlpha),
                    base: base,
                    syntaxTheme: syntaxTheme,
                    minWidth: contentWidth,
                  ),
                  DiffLineKind.removed => _DiffRow(
                    line: line,
                    background: colors.danger.withValues(alpha: bgAlpha),
                    base: base,
                    syntaxTheme: syntaxTheme,
                    minWidth: contentWidth,
                  ),
                  DiffLineKind.context => _DiffRow(
                    line: line,
                    background: null,
                    base: base,
                    syntaxTheme: syntaxTheme,
                    minWidth: contentWidth,
                  ),
                },
            ],
          ),
        );
      },
    );
  }

  /// 解析 apply_patch 信封：隐藏语法噪音（信封/hunk/文件头），
  /// 行归类为增删/上下文，记录文件块语言，统一内容列前缀（对齐缩进）
  static List<_DiffLine> _parse(String diff) {
    final rawLines = diff.split('\n');

    // 模型输出的前缀风格可能不统一：规范格式是 ` 内容`（上下文带 1 空格
    // 前缀）/ `+内容` / `-内容`；也有 `内容` / `- 内容` 的非规范变体。
    // 以多数上下文行的形态为准，统一把内容列对齐到同一起点。
    var contextCount = 0;
    var prefixedContextCount = 0;
    for (final raw in rawLines) {
      if (raw.isNotEmpty &&
          !raw.startsWith('+') &&
          !raw.startsWith('-') &&
          !_isSyntaxNoise(raw)) {
        contextCount++;
        if (raw.startsWith(' ')) prefixedContextCount++;
      }
    }
    // 规范格式：多数上下文行带 1 空格前缀 → 渲染时去掉前缀；
    // 非规范格式：上下文行无前缀 → 增删行去掉符号后紧随的对齐空格。
    // 无上下文行时（如纯 Add File）无法判断风格，默认规范，保内容不误删缩进
    final trimContextPrefix =
        contextCount == 0 || prefixedContextCount > contextCount ~/ 2;

    final lines = <_DiffLine>[];
    Mode? currentLanguage;
    // 行号游标：随上下文/增删行递增，hunk 头重置，文件头归零
    var oldLine = 1;
    var newLine = 1;
    // 当前文件块的增删统计（文件头行显示 +N −M）
    var blockAdded = 0;
    var blockRemoved = 0;
    for (final raw in rawLines) {
      // 文件头：渲染为徽标 + 路径 + 统计，重置行号与统计
      final header = _headerPath(raw);
      if (header != null) {
        lines.add(
          _DiffLine(
            header.$1,
            header.$2,
            null,
            addedCount: blockAdded,
            removedCount: blockRemoved,
          ),
        );
        currentLanguage = _modeForPath(header.$2);
        oldLine = 1;
        newLine = 1;
        blockAdded = 0;
        blockRemoved = 0;
        continue;
      }
      // 信封行：纯语法噪音，不渲染
      if (raw == '*** Begin Patch' || raw == '*** End Patch') {
        continue;
      }
      // hunk 头：解析行号起点（apply_patch 常见简化格式 `@@` 无参数，不重置）
      if (raw.startsWith('@@')) {
        final hunk = RegExp(
          r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@',
        ).firstMatch(raw);
        if (hunk != null) {
          oldLine = int.parse(hunk.group(1)!);
          newLine = int.parse(hunk.group(2)!);
        }
        continue;
      }
      // 尾注：纯语法噪音，不渲染
      if (raw.startsWith('\\ No newline')) {
        continue;
      }
      if (raw.startsWith('+') && !raw.startsWith('+++')) {
        lines.add(
          _DiffLine(
            DiffLineKind.added,
            _contentAfterPrefix(raw, trimContextPrefix),
            currentLanguage,
            oldLineNo: null,
            newLineNo: newLine,
          ),
        );
        newLine++;
        blockAdded++;
        continue;
      }
      if (raw.startsWith('-') && !raw.startsWith('---')) {
        lines.add(
          _DiffLine(
            DiffLineKind.removed,
            _contentAfterPrefix(raw, trimContextPrefix),
            currentLanguage,
            oldLineNo: oldLine,
            newLineNo: null,
          ),
        );
        oldLine++;
        blockRemoved++;
        continue;
      }
      // 上下文行：规范格式去掉 1 空格前缀，非规范格式原样
      final text = trimContextPrefix && raw.startsWith(' ')
          ? raw.substring(1)
          : raw;
      lines.add(
        _DiffLine(
          DiffLineKind.context,
          text,
          currentLanguage,
          oldLineNo: oldLine,
          newLineNo: newLine,
        ),
      );
      oldLine++;
      newLine++;
    }
    return lines;
  }

  /// 若为文件头行则返回 (操作类型, 文件路径)，否则返回 null
  static (DiffLineKind, String)? _headerPath(String raw) {
    const markers = <(String, DiffLineKind)>[
      ('*** Add File: ', DiffLineKind.fileAdd),
      ('*** Update File: ', DiffLineKind.fileUpdate),
      ('*** Delete File: ', DiffLineKind.fileDelete),
      ('*** Move File: ', DiffLineKind.fileMove),
    ];
    for (final (marker, kind) in markers) {
      if (raw.startsWith(marker)) {
        return (kind, raw.substring(marker.length));
      }
    }
    return null;
  }

  /// 信封/hunk 头/文件头/尾注：纯语法噪音
  static bool _isSyntaxNoise(String raw) {
    return raw == '*** Begin Patch' ||
        raw == '*** End Patch' ||
        raw.startsWith('@@') ||
        raw.startsWith('\\ No newline') ||
        raw.startsWith('*** Add File: ') ||
        raw.startsWith('*** Update File: ') ||
        raw.startsWith('*** Delete File: ') ||
        raw.startsWith('*** Move File: ');
  }

  /// 去掉行前缀后的内容：符号后若带对齐空格（非规范 `- x`）一并去掉
  static String _contentAfterPrefix(String raw, bool trimContextPrefix) {
    final content = raw.substring(1);
    if (!trimContextPrefix && content.startsWith(' ')) {
      return content.substring(1);
    }
    return content;
  }
}

enum DiffLineKind {
  fileAdd,
  fileUpdate,
  fileDelete,
  fileMove,
  added,
  removed,
  context,
}

class _DiffLine {
  const _DiffLine(
    this.kind,
    this.text,
    this.language, {
    this.oldLineNo,
    this.newLineNo,
    this.addedCount = 0,
    this.removedCount = 0,
  });

  final DiffLineKind kind;

  /// 内容行为去前缀后的文本；文件头行为文件路径
  final String text;

  /// 所属文件块的语法语言（未知为 null → 纯文本）
  final Mode? language;

  /// 旧文件行号（新增行/文件头无）
  final int? oldLineNo;

  /// 新文件行号（删除行/文件头无）
  final int? newLineNo;

  /// 文件块新增行数（文件头统计用）
  final int addedCount;

  /// 文件块删除行数（文件头统计用）
  final int removedCount;
}

/// 内容行：整行背景（铺满 [minWidth]）+ VSCode 式双列行号 + 可选中内容
class _DiffRow extends StatelessWidget {
  const _DiffRow({
    required this.line,
    required this.background,
    required this.base,
    required this.syntaxTheme,
    required this.minWidth,
  });

  final _DiffLine line;
  final Color? background;
  final TextStyle base;
  final Map<String, TextStyle> syntaxTheme;
  final double minWidth;

  /// 行号列宽：3 位等宽字符（@12px ≈ 22px）
  static const _lineNoWidth = 22.0;

  @override
  Widget build(BuildContext context) {
    final language = line.language;
    final Widget content;
    if (language == null || line.text.isEmpty) {
      content = SelectableText(line.text, style: base);
    } else {
      content = SelectableText.rich(
        highlightToSpan(
          code: line.text,
          language: language,
          baseStyle: base,
          theme: syntaxTheme,
        ),
      );
    }
    // 行号：弱色、不可选中（普通 Text），复制内容不含行号
    final lineNoStyle = base.copyWith(color: base.color!.withValues(alpha: 0.45));
    // 单列行号：新增/上下文显示新行号，删除行显示旧行号
    final lineNo = line.newLineNo ?? line.oldLineNo;
    return Container(
      color: background,
      constraints: BoxConstraints(minWidth: minWidth),
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _lineNoWidth,
            child: Text(
              lineNo?.toString() ?? '',
              style: lineNoStyle,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: content),
        ],
      ),
    );
  }
}

/// 文件头行：操作图标 + 路径加粗 + 变更统计（+N −M），GitHub 风格
class _FileHeader extends StatelessWidget {
  const _FileHeader({required this.line, required this.custom});

  final _DiffLine line;
  final CustomTheme custom;

  @override
  Widget build(BuildContext context) {
    final colors = custom.colors;
    final fontSize = custom.typography.captionSize;
    // 操作类型 → 图标 + 操作色（新建绿 / 修改琥珀 / 删除红 / 移动强调）
    final (iconName, color) = switch (line.kind) {
      DiffLineKind.fileAdd => ('filePlus', colors.success),
      DiffLineKind.fileUpdate => ('pencil', colors.warning),
      DiffLineKind.fileDelete => ('trash', colors.danger),
      _ => ('move', colors.accent),
    };
    final base = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: fontSize,
      height: DiffCodeBlock._lineHeight / fontSize,
      color: colors.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 操作图标（小尺寸，克制低调）
          AppIcon(iconName, size: 11, color: color),
          const SizedBox(width: 6),
          // 路径
          Text(
            line.text,
            style: base.copyWith(fontWeight: FontWeight.w600),
          ),
          // 变更统计（GitHub 风格：+N 绿 / −M 红）
          if (line.addedCount > 0 || line.removedCount > 0) ...[
            const SizedBox(width: 10),
            if (line.addedCount > 0)
              Text(
                '+${line.addedCount}',
                style: base.copyWith(
                  color: colors.success,
                  fontSize: fontSize - 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (line.removedCount > 0)
              Text(
                ' −${line.removedCount}',
                style: base.copyWith(
                  color: colors.danger,
                  fontSize: fontSize - 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
