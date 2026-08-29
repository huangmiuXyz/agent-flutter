/// 内置工具的结果专属渲染 — 替代展开区的通用结果文本。
///
/// 每个 Rust 工具的结果文本都有固定结构（`builtin_tool_renders.dart` 的
/// 参数视图同样与之一一对应），本文件按结构解析后以专属视图呈现：
/// - `shell_command` → 退出码状态胶囊 + 深色终端输出块（ANSI 彩色）
/// - `simulated_terminal` → 终端标识 + 深色终端输出块
/// - `read_file` → 文件头 + 行号 + 按路径扩展名的语法高亮（大文件虚拟滚动）
/// - `grep` / `find_path` / `list_directory` → 元信息说明行 + 逐行配色主体
/// - `apply_patch` → 操作摘要行（新增绿 / 删除红 / 更新琥珀 / 移动强调）
/// - `spawn_sub_agent` / `terminal_send_input` → 结构化标识 + 文本块
/// - `load_skill` → 技能 Markdown 正文
///
/// 解析遵循「结构不匹配即回退」：工具报错时 result 是原始错误字符串，
/// 一律回落 [ToolResultTextView]（与通用渲染一致的 ANSI 彩色段落），
/// 保证任何文本都能展示。大输出经 [VirtualParagraphText] 虚拟滚动，
/// 只构建可见行（与通用渲染的大输出策略一致）。
library;

import 'package:flutter/material.dart';

import 'package:re_highlight/re_highlight.dart';

import 'package:agent/features/chat/custom_tools_render/builtin_tool_renders.dart';
import 'package:agent/features/chat/custom_tools_render/diff_code_block.dart';
import 'package:agent/features/chat/widgets/chat_text_part.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/theme/syntax_theme.dart';
import 'package:agent/widgets/ansi_text.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/highlight_text.dart';
import 'package:agent/widgets/text/virtual_paragraph_text.dart';

// ── 共享原语 ───────────────────────────────────────────────────────────────

/// 等宽基础样式（行高 18 与通用渲染一致）
TextStyle _monoStyle(CustomTheme custom, {Color? color, FontWeight? weight}) {
  return TextStyle(
    fontFamily: custom.typography.fontFamily ?? kDefaultFontFamily,
    fontSize: custom.typography.captionSize,
    height: 18 / custom.typography.captionSize,
    color: color ?? custom.colors.textPrimary,
    fontWeight: weight,
  );
}

/// 内容高度上限：超过后虚拟滚动只构建可见行
double _maxHeight(CustomTheme custom) =>
    custom.controls.chatPartExpandedMaxHeight;

/// 通用结果文本视图（兜底）：ANSI 彩色等宽段落 + 虚拟滚动，
/// 样式与 ChatExpandablePart 的通用输出段一致（成功色基调）
class ToolResultTextView extends StatelessWidget {
  const ToolResultTextView({super.key, required this.text, this.baseColor});

  final String text;

  /// 段落基色；缺省成功色（工具输出 = 正常完成的语义）
  final Color? baseColor;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    if (text.isEmpty) return const SizedBox.shrink();
    final base = _monoStyle(custom, color: baseColor ?? custom.colors.success);
    return VirtualParagraphText(
      text: text,
      splitMode: ParagraphSplitMode.newline,
      preserveEmpty: true,
      fontSize: custom.typography.captionSize,
      lineHeight: 18,
      maxHeight: _maxHeight(custom),
      paragraphPaddingBlock: 0,
      paragraphGap: 4,
      paragraphBuilder: (paragraph, index) => SelectableText.rich(
        TextSpan(
          style: base,
          children: AnsiTextParser().parse(paragraph.text, baseStyle: base),
        ),
      ),
    );
  }
}

/// 深色终端输出块：ANSI 颜色以深色终端为设计基准，配深色容器还原
/// 命令行观感；大输出虚拟滚动封顶（对齐 CodeBlockView 的配色常量）
class TerminalOutputBlock extends StatelessWidget {
  const TerminalOutputBlock({super.key, required this.text});

  final String text;

  static const _background = Color(0xFF282C34);
  static const _border = Color(0xFF3E4451);
  static const _foreground = Color(0xFFABB2BF);

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    if (text.isEmpty) return const SizedBox.shrink();
    final base = _monoStyle(custom, color: _foreground);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _background,
        borderRadius: custom.radii.sm,
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: VirtualParagraphText(
        text: text,
        splitMode: ParagraphSplitMode.newline,
        preserveEmpty: true,
        fontSize: custom.typography.captionSize,
        lineHeight: 18,
        maxHeight: _maxHeight(custom),
        paragraphPaddingBlock: 0,
        paragraphGap: 4,
        paragraphBuilder: (paragraph, index) => SelectableText.rich(
          TextSpan(
            style: base,
            children: AnsiTextParser().parse(paragraph.text, baseStyle: base),
          ),
        ),
      ),
    );
  }
}

/// `----` 分隔的结构化结果：头部元信息行 + 主体行 + 尾部 `[...]` 提示
class _SectionedResult {
  _SectionedResult._(this.header, this.body, this.footer, this.parsed);

  /// `----` 前的元信息行
  final List<String> header;

  /// `----` 后、尾注前的主体行
  final List<String> body;

  /// 末尾 `[...]` 提示（翻页/截断），无则 null
  final String? footer;

  /// 是否符合 `----` 分隔结构（否则应回退通用渲染）
  final bool parsed;

  /// join 后的头部文本（解析失败回退用）
  String get headerText => header.join('\n');
  String get bodyText => body.join('\n');
}

const _separator = '----------------------------------------';

/// 解析 `元信息\n----\n主体...\n\n[尾注]` 结构；不含分隔线时 parsed=false
_SectionedResult? _splitSections(String rawResult) {
  final lines = rawResult.split('\n');
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }
  final sep = lines.indexOf(_separator);
  if (sep < 0) return null;
  final rest = lines.sublist(sep + 1);

  // 尾注：空行 + 单行 `[...]`，可能连续多条（截断 + 翻页提示）
  final footers = <String>[];
  while (rest.length >= 2 &&
      rest.last.startsWith('[') &&
      rest.last.endsWith(']') &&
      rest[rest.length - 2].trim().isEmpty) {
    footers.insert(0, rest.removeLast());
    rest.removeLast();
  }

  return _SectionedResult._(
    lines.sublist(0, sep),
    rest,
    footers.isEmpty ? null : footers.join('\n'),
    true,
  );
}

// ── 各工具结果视图 ──────────────────────────────────────────────────────────

/// `shell_command` — 退出码胶囊（超时提示）+ 深色终端输出块。
/// 结果格式：`[command timed out after N milliseconds\n]exit code: N\n<body>`；
/// 报错（无法执行）时无退出码前缀，回退通用渲染。
class ShellResultView extends StatelessWidget {
  const ShellResultView({super.key, required this.rawResult});

  final String rawResult;

  static final _timeoutRe = RegExp(
    r'^command timed out after (\d+) milliseconds\r?\n',
  );
  static final _exitCodeRe = RegExp(r'^exit code: (-?\d+)\r?\n');

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    var text = rawResult;
    String? timeoutMs;
    final timeout = _timeoutRe.firstMatch(text);
    if (timeout != null) {
      timeoutMs = timeout.group(1);
      text = text.substring(timeout.end);
    }
    final exit = _exitCodeRe.firstMatch(text);
    if (exit == null) {
      // 工具报错（无退出码行）：回退通用渲染
      return ToolResultTextView(text: rawResult);
    }
    final exitCode = int.parse(exit.group(1)!);
    text = text.substring(exit.end);
    final hasOutput = text.isNotEmpty && text != '(no output)';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ExitCodeChip(custom: custom, code: exitCode),
            if (timeoutMs != null) ...[
              const SizedBox(width: 8),
              Text(
                '超时 $timeoutMs ms',
                style: _monoStyle(
                  custom,
                  color: custom.colors.warning,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        if (hasOutput) ...[
          SizedBox(height: custom.spacing.sm),
          TerminalOutputBlock(text: text),
        ],
      ],
    );
  }
}

/// 退出码胶囊：0 成功绿，非 0 失败红
class _ExitCodeChip extends StatelessWidget {
  const _ExitCodeChip({required this.custom, required this.code});

  final CustomTheme custom;
  final int code;

  @override
  Widget build(BuildContext context) {
    final ok = code == 0;
    final color = ok ? custom.colors.success : custom.colors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: custom.brightness == Brightness.dark ? 0.18 : 0.08,
        ),
        borderRadius: custom.radii.full,
      ),
      child: Text(
        ok ? '成功' : '退出码 $code',
        style: TextStyle(
          fontSize: custom.typography.captionSize - 1,
          height: 1.4,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// `simulated_terminal` — 终端标识 + 深色终端输出块。
/// 结果格式：`[Terminal created|reused. terminal_id: x]\n<body>`；
/// 终端被关闭等错误回退通用渲染。
class SimulatedTerminalResultView extends StatelessWidget {
  const SimulatedTerminalResultView({super.key, required this.rawResult});

  final String rawResult;

  static final _headerRe = RegExp(
    r'^\[(Terminal (created|reused))\. terminal_id: (.+?)\]\r?\n',
  );

  @override
  Widget build(BuildContext context) {
    final match = _headerRe.firstMatch(rawResult);
    if (match == null) return ToolResultTextView(text: rawResult);
    final custom = CustomTheme.of(context);
    final created = match.group(2) == 'created';
    final terminalId = match.group(3)!;
    final body = rawResult.substring(match.end);
    final hasOutput = body.isNotEmpty && body != '(命令执行完毕，无输出)';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ToolArgCaptions(
          items: [('终端', terminalId), ('状态', created ? '新建' : '复用')],
        ),
        if (hasOutput) ...[
          SizedBox(height: custom.spacing.sm),
          TerminalOutputBlock(text: body),
        ],
      ],
    );
  }
}

/// `terminal_send_input` — 目标终端标识 + 输入回执。
/// 结果格式：`[terminal_id: x]\n<body>`。
class TerminalInputResultView extends StatelessWidget {
  const TerminalInputResultView({super.key, required this.rawResult});

  final String rawResult;

  @override
  Widget build(BuildContext context) {
    const prefix = '[terminal_id: ';
    if (!rawResult.startsWith(prefix)) {
      return ToolResultTextView(text: rawResult);
    }
    final end = rawResult.indexOf(']\n', prefix.length);
    if (end < 0) return ToolResultTextView(text: rawResult);
    final custom = CustomTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ToolArgCaptions(
          items: [('终端', rawResult.substring(prefix.length, end))],
        ),
        SizedBox(height: custom.spacing.xs),
        ToolTaskBlock(text: rawResult.substring(end + 2), mono: true),
      ],
    );
  }
}

/// `read_file` — 文件头 + 元信息 + 带行号的语法高亮正文（虚拟滚动）。
/// 结果格式：`文件: p\n大小: N 字节 | 行数: M\n[行区间: a–b\n]----\n<正文>[\n\n[尾注]]`；
/// 图片读取（`[图片已读取]`）与报错不匹配该结构，回退通用渲染。
class ReadFileResultView extends StatelessWidget {
  const ReadFileResultView({
    super.key,
    required this.rawArguments,
    required this.rawResult,
  });

  final String rawArguments;
  final String rawResult;

  static final _metaRe = RegExp(r'^大小: (\d+) 字节 \| 行数: (\d+)$');
  static final _rangeRe = RegExp(r'^行区间: (\d+)–(\d+)$');

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final sections = _splitSections(rawResult);
    if (sections == null || sections.header.isEmpty) {
      return ToolResultTextView(text: rawResult);
    }

    // 头部：文件 / 大小|行数 / [行区间]
    final header = sections.header;
    if (!header[0].startsWith('文件: ')) {
      return ToolResultTextView(text: rawResult);
    }
    final path = header[0].substring('文件: '.length);
    final meta = header.length > 1 ? _metaRe.firstMatch(header[1]) : null;
    if (meta == null) return ToolResultTextView(text: rawResult);
    final sizeBytes = meta.group(1)!;
    final totalLines = meta.group(2)!;
    final range = header.length > 2 ? _rangeRe.firstMatch(header[2]) : null;
    final startLine = range != null ? int.parse(range.group(1)!) : 1;
    final rangeLabel = range != null
        ? '${range.group(1)} – ${range.group(2)}'
        : null;

    // 正文按路径扩展名做语法高亮；正文可能为空（区间越界时提示文本
    // 直接以 `[...]` 出现在分隔线后，视为尾注而非正文行）
    final language = DiffCodeBlock.modeForPath(path);
    var bodyText = sections.bodyText;
    var footer = sections.footer;
    if (bodyText.length > 1 &&
        bodyText.startsWith('[') &&
        bodyText.endsWith(']')) {
      footer = footer == null ? bodyText : '$bodyText\n$footer';
      bodyText = '';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon('file', size: 11, color: custom.colors.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: SelectableText(
                path,
                style: _monoStyle(custom, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
        SizedBox(height: custom.spacing.xs),
        ToolArgCaptions(
          items: [
            ('大小', '$sizeBytes B'),
            ('行数', totalLines),
            if (rangeLabel != null) ('显示区间', rangeLabel),
          ],
        ),
        if (bodyText.isNotEmpty) ...[
          SizedBox(height: custom.spacing.sm),
          _FileContentLines(
            text: bodyText,
            startLine: startLine,
            language: language,
          ),
        ],
        if (footer != null) ...[
          SizedBox(height: custom.spacing.xs),
          Text(
            footer,
            style: _monoStyle(custom, color: custom.colors.textDisabled),
          ),
        ],
      ],
    );
  }
}

/// 带行号的正文行：行号弱色不可选，内容按语言高亮；大文件虚拟滚动
class _FileContentLines extends StatelessWidget {
  const _FileContentLines({
    required this.text,
    required this.startLine,
    required this.language,
  });

  final String text;
  final int startLine;
  final Mode? language;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final base = _monoStyle(custom);
    final gutterStyle = base.copyWith(
      color: base.color!.withValues(alpha: 0.45),
    );
    final syntaxTheme = buildSyntaxTheme(custom.colors);
    return VirtualParagraphText(
      text: text,
      splitMode: ParagraphSplitMode.newline,
      preserveEmpty: true,
      fontSize: custom.typography.captionSize,
      lineHeight: 18,
      maxHeight: _maxHeight(custom),
      paragraphPaddingBlock: 0,
      paragraphGap: 0,
      paragraphBuilder: (paragraph, index) {
        final line = paragraph.text;
        final lineNo = (startLine + index).toString();
        final content = language == null || line.isEmpty
            ? TextSpan(text: line, style: base)
            : highlightToSpan(
                code: line,
                language: language!,
                baseStyle: base,
                theme: syntaxTheme,
              );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text(
                lineNo,
                style: gutterStyle,
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: SelectableText.rich(content, style: base)),
          ],
        );
      },
    );
  }
}

/// `grep` — 元信息说明 + `路径:行号: 内容` 逐行配色（虚拟滚动）。
class GrepResultView extends StatelessWidget {
  const GrepResultView({super.key, required this.rawResult});

  final String rawResult;

  static final _scanRe = RegExp(
    r'扫描 (\d+) 个文本文件（跳过 (\d+) 个二进制/非 UTF-8 文件），共 (\d+) 处匹配',
  );
  static final _pageRe = RegExp(r'^显示第 (\d+)–(\d+) 条（每页 \d+ 条）$');
  static final _matchRe = RegExp(r'^(.+):(\d+): (.*)$');

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final sections = _splitSections(rawResult);
    // 零匹配时主体为空但仍展示元信息；无分隔线结构（报错）才回退
    if (sections == null) {
      return ToolResultTextView(text: rawResult);
    }

    final captions = <(String, String)>[];
    for (final line in sections.header) {
      final scan = _scanRe.firstMatch(line);
      if (scan != null) {
        captions.add(('匹配', '共 ${scan.group(3)} 处'));
        continue;
      }
      final page = _pageRe.firstMatch(line);
      if (page != null) {
        captions.add(('显示', '第 ${page.group(1)} – ${page.group(2)} 条'));
      }
    }

    final base = _monoStyle(custom);
    final pathStyle = base.copyWith(color: custom.colors.textSecondary);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ToolArgCaptions(items: captions),
        if (sections.body.isNotEmpty) ...[
          SizedBox(height: custom.spacing.sm),
          VirtualParagraphText(
            text: sections.bodyText,
            splitMode: ParagraphSplitMode.newline,
            preserveEmpty: true,
            fontSize: custom.typography.captionSize,
            lineHeight: 18,
            maxHeight: _maxHeight(custom),
            paragraphPaddingBlock: 0,
            paragraphGap: 0,
            paragraphBuilder: (paragraph, index) {
              final match = _matchRe.firstMatch(paragraph.text);
              final span = match == null
                  ? TextSpan(text: paragraph.text, style: base)
                  : TextSpan(
                      children: [
                        TextSpan(
                          text: '${match.group(1)}:${match.group(2)}',
                          style: pathStyle,
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(text: match.group(3), style: base),
                      ],
                    );
              return SelectableText.rich(span, style: base);
            },
          ),
        ],
        if (sections.footer != null) ...[
          SizedBox(height: custom.spacing.xs),
          Text(
            sections.footer!,
            style: _monoStyle(custom, color: custom.colors.textDisabled),
          ),
        ],
      ],
    );
  }
}

/// `find_path` — 元信息说明 + 匹配路径列表（虚拟滚动）。
class FindPathResultView extends StatelessWidget {
  const FindPathResultView({super.key, required this.rawResult});

  final String rawResult;

  static final _foundRe = RegExp(r'^找到 (\d+) 个匹配');
  static final _pageRe = RegExp(r'显示第 (\d+)–(\d+) 条');

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final sections = _splitSections(rawResult);
    // 零匹配时主体为空但仍展示元信息；无分隔线结构（报错）才回退
    if (sections == null) {
      return ToolResultTextView(text: rawResult);
    }

    final captions = <(String, String)>[];
    for (final line in sections.header) {
      final found = _foundRe.firstMatch(line);
      if (found != null) {
        captions.add(('匹配', '${found.group(1)} 个'));
      }
      final page = _pageRe.firstMatch(line);
      if (page != null) {
        captions.add(('显示', '第 ${page.group(1)} – ${page.group(2)} 条'));
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ToolArgCaptions(items: captions),
        if (sections.body.isNotEmpty) ...[
          SizedBox(height: custom.spacing.sm),
          VirtualParagraphText(
            text: sections.bodyText,
            splitMode: ParagraphSplitMode.newline,
            preserveEmpty: true,
            fontSize: custom.typography.captionSize,
            lineHeight: 18,
            maxHeight: _maxHeight(custom),
            paragraphPaddingBlock: 0,
            paragraphGap: 0,
            paragraphBuilder: (paragraph, index) =>
                SelectableText(paragraph.text, style: _monoStyle(custom)),
          ),
        ],
        if (sections.footer != null) ...[
          SizedBox(height: custom.spacing.xs),
          Text(
            sections.footer!,
            style: _monoStyle(custom, color: custom.colors.textDisabled),
          ),
        ],
      ],
    );
  }
}

/// `list_directory` — 目录路径 + 子目录/文件逐行配色（目录绿、大小弱色）。
class ListDirResultView extends StatelessWidget {
  const ListDirResultView({super.key, required this.rawResult});

  final String rawResult;

  static final _entryRe = RegExp(r'^(.*) \(([^)]+)\)$');

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final sections = _splitSections(rawResult);
    if (sections == null || sections.header.isEmpty) {
      return ToolResultTextView(text: rawResult);
    }
    final dirLine = sections.header.firstWhere(
      (l) => l.startsWith('目录: '),
      orElse: () => '',
    );
    if (dirLine.isEmpty) return ToolResultTextView(text: rawResult);

    final base = _monoStyle(custom);
    final dirStyle = base.copyWith(color: custom.colors.success);
    final sizeStyle = base.copyWith(color: custom.colors.textSecondary);
    final metaStyle = base.copyWith(color: custom.colors.textDisabled);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ToolArgCaptions(items: [('目录', dirLine.substring('目录: '.length))]),
        SizedBox(height: custom.spacing.sm),
        VirtualParagraphText(
          text: sections.bodyText,
          splitMode: ParagraphSplitMode.newline,
          preserveEmpty: false,
          fontSize: custom.typography.captionSize,
          lineHeight: 18,
          maxHeight: _maxHeight(custom),
          paragraphPaddingBlock: 0,
          paragraphGap: 0,
          paragraphBuilder: (paragraph, index) {
            final line = paragraph.text;
            final span = _entrySpan(line, base, dirStyle, sizeStyle, metaStyle);
            return SelectableText.rich(span, style: base);
          },
        ),
      ],
    );
  }

  /// 行分类：`  name/` 目录（绿）；`  name (size)` 文件 + 弱色大小；
  /// `子目录（N 个）:` 等节标题与空态为弱色元信息
  TextSpan _entrySpan(
    String line,
    TextStyle base,
    TextStyle dirStyle,
    TextStyle sizeStyle,
    TextStyle metaStyle,
  ) {
    if (!line.startsWith('  ') || line.length <= 2) {
      return TextSpan(text: line, style: metaStyle);
    }
    final entry = line.substring(2);
    if (entry.endsWith('/')) {
      return TextSpan(text: entry, style: dirStyle);
    }
    final file = _entryRe.firstMatch(entry);
    if (file != null) {
      return TextSpan(
        children: [
          TextSpan(text: file.group(1), style: base),
          TextSpan(text: ' (${file.group(2)})', style: sizeStyle),
        ],
      );
    }
    return TextSpan(text: entry, style: base);
  }
}

/// `apply_patch` — 操作摘要行：新增绿 / 删除红 / 更新琥珀 / 移动强调。
/// 结果格式（每行一条）：`+ added: p` / `- deleted: p` / `~ updated: p` /
/// `~ moved: a -> b`；报错时回退通用渲染。
class PatchResultView extends StatelessWidget {
  const PatchResultView({super.key, required this.rawResult});

  final String rawResult;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final rows = <Widget>[];
    for (final line in rawResult.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final row = _summaryRow(custom, trimmed);
      if (row == null) {
        // 不符合摘要格式（报错/未知文案）：整段回退通用渲染
        return ToolResultTextView(text: rawResult);
      }
      rows.add(row);
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, row) in rows.indexed) ...[
          if (index > 0) SizedBox(height: custom.spacing.xs),
          row,
        ],
      ],
    );
  }

  Widget? _summaryRow(CustomTheme custom, String line) {
    final summary = switch (line) {
      _ when line.startsWith('+ added: ') => (
        'filePlus',
        custom.colors.success,
        '新增',
        line.substring('+ added: '.length),
      ),
      _ when line.startsWith('- deleted: ') => (
        'trash',
        custom.colors.danger,
        '删除',
        line.substring('- deleted: '.length),
      ),
      _ when line.startsWith('~ moved: ') => (
        'move',
        custom.colors.accent,
        '移动',
        line.substring('~ moved: '.length).replaceAll(' -> ', ' → '),
      ),
      _ when line.startsWith('~ updated: ') => (
        'pencil',
        custom.colors.warning,
        '更新',
        line.substring('~ updated: '.length),
      ),
      _ => null,
    };
    if (summary == null) return null;
    final (iconName, color, label, path) = summary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(iconName, size: 11, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: SelectableText(
            '$label $path',
            style: _monoStyle(custom, color: color, weight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// `spawn_sub_agent` — 完成态解析为「标识 + 任务 + 结果」，其余整块文本展示。
/// 同步结果格式：`[子智能体「name」已完成 · 会话 sid]\n任务：t\n结果：r`。
class SubAgentResultView extends StatelessWidget {
  const SubAgentResultView({super.key, required this.rawResult});

  final String rawResult;

  static final _doneRe = RegExp(
    r'^\[子智能体「(.+?)」已完成 · 会话 (.+?)\]\s*\n任务：([\s\S]*?)\n结果：([\s\S]*)$',
  );

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final match = _doneRe.firstMatch(rawResult.trim());
    if (match == null) {
      // 后台启动提示 / 未提交总结等：整段按文本块展示
      return ToolTaskBlock(text: rawResult);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon('robot', size: 11, color: custom.colors.accent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '「${match.group(1)}」已完成 · 会话 ${match.group(2)}',
                style: _monoStyle(custom, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
        SizedBox(height: custom.spacing.sm),
        ToolTaskBlock(text: match.group(3)!),
        SizedBox(height: custom.spacing.xs),
        ToolTaskBlock(text: match.group(4)!),
      ],
    );
  }
}

/// `load_skill` — 技能 Markdown 正文（复用聊天文本渲染管线）。
class SkillResultView extends StatelessWidget {
  const SkillResultView({super.key, required this.rawResult});

  final String rawResult;

  @override
  Widget build(BuildContext context) {
    if (rawResult.isEmpty) return const SizedBox.shrink();
    return ChatTextPart(content: rawResult, streaming: false);
  }
}
