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

/// 增量 diff 解析器 — 只处理新增文本。
///
/// 流式期间每次到达的补丁文本都是「前缀追加」（相同前缀 + 新尾部），
/// [feed] 只解析增量部分：完整行立即走状态机生成 [DiffLine]，
/// 未完成行（无行尾换行）留在 [pending] 供渲染层原位更新。
///
/// 语义对齐一次性全量解析 [`DiffCodeBlock.parseDiff`]，差异仅一处：
/// 「上下文行前缀风格」从全量多数派判定改为「首个内容行到达时定型」
/// （流式无法预知未来行），对非规范输出（混用前缀风格）的视觉影响
/// 仅是前缀空格是否保留。
class DiffParser {
  /// 已提交的完整行
  final List<DiffLine> lines = [];

  /// 文件头事件（kind, path）— 到达即记录，供纯文件操作分支增量渲染
  final List<(DiffLineKind, String)> headers = [];

  /// 是否出现过内容行（非空、非信封/文件头/@@/尾注）
  bool hasContentLines = false;

  /// 未完成行文本（无行尾换行）
  String pending = '';

  /// 是否可见内容行（含未完成行）：纯文件操作分支的判定依据。
  /// 未完成行按全量解析语义参与分类（`+hel` 未换行也算内容行）。
  bool get hasVisibleContent {
    if (hasContentLines) return true;
    final raw = pending;
    if (raw.isEmpty) return false;
    if (raw.startsWith('+') || raw.startsWith('-')) return true;
    final trimmed = raw.trimLeft();
    return trimmed.isNotEmpty &&
        !trimmed.startsWith('***') &&
        !trimmed.startsWith('@@') &&
        !trimmed.startsWith('\\ No newline');
  }

  // ── 解析状态（对齐静态 _parse）──
  Mode? _language;
  int _oldLine = 1;
  int _newLine = 1;
  int _blockAdded = 0;
  int _blockRemoved = 0;
  // 上下文前缀风格：首个上下文行到达时定型（流式增量近似全量多数派判定）
  bool _styleFixed = false;
  bool _trimContextPrefix = true;
  // 上一块（已结束）的变更统计：header 行显示的是前一块的统计（首个为 0）
  int _lastBlockAdded = 0;
  int _lastBlockRemoved = 0;

  static final RegExp _hunkRe =
      RegExp(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@');

  /// 追加新文本（增量）：处理新出现的完整行，未完成行留待下次
  void feed(String delta) {
    if (delta.isEmpty) return;
    pending += delta;
    final nl = pending.lastIndexOf('\n');
    if (nl < 0) return;
    final head = pending.substring(0, nl);
    pending = pending.substring(nl + 1);
    // 上一轮 pending 恰好为空、本轮 delta 以换行开头时没有完整行
    if (head.isEmpty) return;
    for (final raw in head.split('\n')) {
      _processLine(raw);
    }
  }

  /// 流结束（未完成行保持可见）
  void flush() {}

  /// 未完成行按当前文本分类（不提交、不动游标/统计）
  DiffLine? pendingLine() {
    final raw = pending;
    if (raw.isEmpty) return null;
    if (raw.startsWith('+') && !raw.startsWith('+++')) {
      return DiffLine(
        DiffLineKind.added,
        _contentAfterPrefix(raw),
        _language,
        newLineNo: _newLine,
      );
    }
    if (raw.startsWith('-') && !raw.startsWith('---')) {
      return DiffLine(
        DiffLineKind.removed,
        _contentAfterPrefix(raw),
        _language,
        oldLineNo: _oldLine,
      );
    }
    final text =
        _trimContextPrefix && raw.startsWith(' ') ? raw.substring(1) : raw;
    return DiffLine(
      DiffLineKind.context,
      text,
      _language,
      oldLineNo: _oldLine,
      newLineNo: _newLine,
    );
  }

  void _processLine(String raw) {
    // 信封行：语法噪音，不产生行
    if (raw == '*** Begin Patch' || raw == '*** End Patch') {
      return;
    }
    // hunk 头：解析行号起点（apply_patch 常见简化格式 `@@` 无参数，不重置）
    if (raw.startsWith('@@')) {
      final hunk = _hunkRe.firstMatch(raw);
      if (hunk != null) {
        _oldLine = int.parse(hunk.group(1)!);
        _newLine = int.parse(hunk.group(2)!);
      }
      return;
    }
    // 尾注：语法噪音
    if (raw.startsWith('\\ No newline')) {
      return;
    }
    // 文件头：开启新块（提交上一个文件头、重置行号/统计/语言）
    final header = DiffCodeBlock._headerPath(raw);
    if (header != null) {
      // 刚结束的块统计结算：header 行显示的是前一块的 +N −M（首个为 0）
      _lastBlockAdded = _blockAdded;
      _lastBlockRemoved = _blockRemoved;
      _blockAdded = 0;
      _blockRemoved = 0;
      // 立即提交（此时当前块尚未有内容行，append 即块首）
      lines.add(DiffLine(
        header.$1,
        header.$2,
        null,
        addedCount: _lastBlockAdded,
        removedCount: _lastBlockRemoved,
      ));
      _language = DiffCodeBlock._modeForPath(header.$2);
      _oldLine = 1;
      _newLine = 1;
      headers.add(header);
      return;
    }
    // 增删行
    if (raw.startsWith('+') && !raw.startsWith('+++')) {
      hasContentLines = true;
      _addLine(DiffLineKind.added, _contentAfterPrefix(raw), null, _newLine);
      _newLine++;
      _blockAdded++;
      return;
    }
    if (raw.startsWith('-') && !raw.startsWith('---')) {
      hasContentLines = true;
      _addLine(DiffLineKind.removed, _contentAfterPrefix(raw), _oldLine, null);
      _oldLine++;
      _blockRemoved++;
      return;
    }
    // 上下文行：首个上下文行即定型前缀风格（近似全量多数派判定，
    // 流式无法预知未来行，纯 context 场景也能立即渲染）。
    // `*** Environment ID` 等不匹配文件头的 `***` 行也在此列，
    // 对齐原全量解析：作为上下文行渲染（不算内容行，对齐纯文件操作判定）
    if (raw.isNotEmpty && !raw.startsWith('***')) hasContentLines = true;
    if (!_styleFixed) {
      _styleFixed = true;
      _trimContextPrefix = raw.startsWith(' ');
    }
    _addContextLine(raw);
  }

  void _addLine(DiffLineKind kind, String text, int? oldNo, int? newNo) {
    lines.add(DiffLine(
      kind,
      text,
      _language,
      oldLineNo: oldNo,
      newLineNo: newNo,
    ));
  }

  void _addContextLine(String raw) {
    final text =
        _trimContextPrefix && raw.startsWith(' ') ? raw.substring(1) : raw;
    _addLine(DiffLineKind.context, text, _oldLine, _newLine);
    _oldLine++;
    _newLine++;
  }

  String _contentAfterPrefix(String raw) {
    final content = raw.substring(1);
    if (!_trimContextPrefix && content.startsWith(' ')) {
      return content.substring(1);
    }
    return content;
  }
}


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
class DiffCodeBlock extends StatefulWidget {
  /// Unified diff 原文（apply_patch 信封格式）
  final String diff;

  const DiffCodeBlock({super.key, required this.diff});

  @override
  State<DiffCodeBlock> createState() => _DiffCodeBlockState();

  /// 解析结果缓存：build 可被父级频繁触发（流式更新/主题切换/列表重建），
  /// 同一 diff 不重复解析。
  static final Map<String, List<DiffLine>> _parseCache = {};
  static const _parseCacheLimit = 32;

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

  /// 带缓存的解析入口：同一 diff 不重复解析（build 可被父级频繁触发）
  static List<DiffLine> parseDiff(String diff) {
    final cached = _parseCache[diff];
    if (cached != null) return cached;
    final lines = _parse(diff);
    _parseCache[diff] = lines;
    if (_parseCache.length > _parseCacheLimit) {
      final keys = _parseCache.keys.take(_parseCache.length ~/ 2).toList();
      for (final key in keys) {
        _parseCache.remove(key);
      }
    }
    return lines;
  }



  /// 解析 apply_patch 信封：隐藏语法噪音（信封/hunk/文件头），
  /// 行归类为增删/上下文，记录文件块语言，统一内容列前缀（对齐缩进）
  static List<DiffLine> _parse(String diff) {
    final rawLines = diff.split('\n');
    // 去掉末尾空白行：diff 常以换行结尾，split 会拆出空串，
    // 若保留会被当作空上下文行渲染成一行空的代码行
    while (rawLines.isNotEmpty && rawLines.last.trim().isEmpty) {
      rawLines.removeLast();
    }

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

    final lines = <DiffLine>[];
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
          DiffLine(
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
          DiffLine(
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
          DiffLine(
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
        DiffLine(
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
      // 模型实际输出为 `*** Move to: new/path`（Rust 端 MOVE_TO_MARKER），
      // 若不识别会被当作上下文代码行渲染
      ('*** Move to: ', DiffLineKind.fileMove),
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
        raw.startsWith('*** Move File: ') ||
        raw.startsWith('*** Move to: ');
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
class _DiffCodeBlockState extends State<DiffCodeBlock> {
  DiffParser _parser = DiffParser();

  /// 已提交行的 widget 缓存：增量更新时只 append 新行，
  /// 旧行 widget 实例不变 → element 复用，不重新 build/布局/高亮
  final List<Widget> _rowWidgets = [];
  double? _builtWidth;
  Object? _builtTheme;

  @override
  void initState() {
    super.initState();
    _parser.feed(widget.diff);
  }

  @override
  void didUpdateWidget(covariant DiffCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final diff = widget.diff;
    if (diff == oldWidget.diff) return;
    if (diff.length > oldWidget.diff.length &&
        diff.startsWith(oldWidget.diff)) {
      // 流式纯追加：只解析增量（未完成行由 build 按最新文本原位替换）
      _parser.feed(diff.substring(oldWidget.diff.length));
    } else {
      // 整体替换（重试/解码恢复/工具完成覆盖）：重置并全量解析
      _parser = DiffParser()..feed(diff);
      _rowWidgets.clear();
      _builtWidth = null;
      _builtTheme = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.diff.isEmpty) {
      return const SizedBox.shrink();
    }
    final custom = CustomTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // 短行背景铺满内容宽度（横向滚动时随内容延伸）
        final contentWidth = constraints.maxWidth;
        if (_builtWidth != contentWidth || !identical(_builtTheme, custom)) {
          // 窗口尺寸/主题变化：低频全量重建
          _builtWidth = contentWidth;
          _builtTheme = custom;
          _rowWidgets.clear();
          for (final line in _parser.lines) {
            _rowWidgets.add(DiffLineView(line: line, minWidth: contentWidth));
          }
        } else {
          // 增量：只构建新完成的行
          for (var i = _rowWidgets.length; i < _parser.lines.length; i++) {
            _rowWidgets.add(
              DiffLineView(line: _parser.lines[i], minWidth: contentWidth),
            );
          }
        }
        // 未完成行：随文本增长原位替换
        final pendingLine = _parser.pendingLine();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in _rowWidgets) row,
              if (pendingLine != null)
                DiffLineView(line: pendingLine, minWidth: contentWidth),
            ],
          ),
        );
      },
    );
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

/// 单行 diff 数据（文件头行/增删行/上下文行），解析结果可缓存共享
class DiffLine {
  const DiffLine(
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

/// 单行 diff 渲染（文件头行/增删行/上下文行）。
///
/// 供 [DiffCodeBlock] 整块渲染使用；行背景铺满 [minWidth]
/// （默认 0：tight 约束下自动填满可用宽度）。
class DiffLineView extends StatelessWidget {
  const DiffLineView({
    super.key,
    required this.line,
    this.minWidth = 0,
  });

  final DiffLine line;
  final double minWidth;

  /// 行号列宽：3 位等宽字符（@12px ≈ 22px）
  static const _lineNoWidth = 22.0;

  static const _lineHeight = 18.0;

  @override
  Widget build(BuildContext context) {
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

    return switch (line.kind) {
      DiffLineKind.fileAdd ||
      DiffLineKind.fileUpdate ||
      DiffLineKind.fileDelete ||
      DiffLineKind.fileMove => _buildFileHeader(custom, fontSize),
      DiffLineKind.added => _buildRow(
        base,
        syntaxTheme,
        colors.success.withValues(
          alpha: custom.brightness == Brightness.dark ? 0.15 : 0.08,
        ),
      ),
      DiffLineKind.removed => _buildRow(
        base,
        syntaxTheme,
        colors.danger.withValues(
          alpha: custom.brightness == Brightness.dark ? 0.15 : 0.08,
        ),
      ),
      DiffLineKind.context => _buildRow(base, syntaxTheme, null),
    };
  }

  /// 文件头行：操作图标 + 路径加粗 + 变更统计（+N −M），GitHub 风格
  Widget _buildFileHeader(CustomTheme custom, double fontSize) {
    final colors = custom.colors;
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
      height: _lineHeight / fontSize,
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

  /// 内容行：整行背景（铺满 [minWidth]）+ VSCode 式行号 + 可选中内容
  Widget _buildRow(
    TextStyle base,
    Map<String, TextStyle> syntaxTheme,
    Color? background,
  ) {
    final Widget content;
    if (line.language == null || line.text.isEmpty) {
      content = SelectableText(line.text, style: base, maxLines: 1);
    } else {
      content = SelectableText.rich(
        highlightToSpan(
          code: line.text,
          language: line.language!,
          baseStyle: base,
          theme: syntaxTheme,
        ),
        style: base,
        maxLines: 1,
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
