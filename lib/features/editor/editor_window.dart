/// 编辑器子窗口 — 使用 code_forge 编辑任意文本文件。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:code_forge/code_forge.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

import 'language_map.dart';

/// 在子窗口中打开一个文件进行编辑。
class EditorWindow extends StatefulWidget {
  final String filePath;
  const EditorWindow({super.key, required this.filePath});

  @override
  State<EditorWindow> createState() => _EditorWindowState();
}

class _EditorWindowState extends State<EditorWindow> {
  CodeForgeController? _controller;
  late final UndoRedoController _undoController;
  bool _ready = false;
  String? _error;

  // 诊断面板
  List<LspErrors> _diagnostics = [];
  double _diagnosticPanelHeight = 150;
  bool _diagnosticPanelVisible = false;
  @override
  void initState() {
    super.initState();
    _undoController = UndoRedoController();
    _initAndOpen();
  }

  Future<void> _initAndOpen() async {
    try {
      await _ensureRustLibInitialized();
    } catch (e) {
      debugPrint('code_forge RustLib init error: $e');
    }

    final config = configFor(widget.filePath);

    LspConfig? lsp;
    if (config?.lspFactory != null) {
      lsp = await tryStartLsp(widget.filePath);
    }

    try {
      _controller = CodeForgeController(lspConfig: lsp);
    } catch (e) {
      debugPrint('CodeForgeController init error: $e');
      if (mounted) {
        setState(() => _error = '无法加载编辑器引擎: $e');
      }
      return;
    }
    _controller!.text = _readFile();

    // 监听诊断更新
    _controller!.diagnosticsNotifier.addListener(_onDiagnosticsChanged);

    if (mounted) setState(() => _ready = true);
  }

  void _onDiagnosticsChanged() {
    if (_controller == null) return;
    final diags = _controller!.diagnosticsNotifier.value;
    if (mounted) {
      setState(() {
        _diagnostics = diags;
        _diagnosticPanelVisible = diags.isNotEmpty;
      });
    }
  }

  Mode? get _language => configFor(widget.filePath)?.mode;

  Future<void> _ensureRustLibInitialized() async {
    try {
      await RustLib.init();
      return;
    } on StateError {
      return;
    } catch (_) {}

    final libDir = Directory(
      '.patches/code_forge/rust/target/release',
    ).absolute.path;

    String libName;
    if (Platform.isMacOS) {
      libName = 'libcode_forge.dylib';
    } else if (Platform.isWindows) {
      libName = 'code_forge.dll';
    } else if (Platform.isLinux) {
      libName = 'libcode_forge.so';
    } else {
      throw UnsupportedError(
        'Unsupported platform: ${Platform.operatingSystem}',
      );
    }

    final libPath = '$libDir${Platform.pathSeparator}$libName';
    if (!File(libPath).existsSync()) {
      throw FileSystemException('code_forge native library not found', libPath);
    }

    final lib = ExternalLibrary.open(libPath);
    await RustLib.init(externalLibrary: lib);
  }

  String _readFile() {
    final file = File(widget.filePath);
    return file.existsSync() ? file.readAsStringSync() : '';
  }

  @override
  void dispose() {
    _controller?.diagnosticsNotifier.removeListener(_onDiagnosticsChanged);
    _controller?.dispose();
    _undoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller == null) return;
    try {
      await File(widget.filePath).writeAsString(_controller!.text);
    } catch (_) {}
  }

  void _scrollToLine(int line) {
    // 滚动到诊断行
    _controller?.scrollToLine(line);
    // 将光标移动到该行
    final offset = _controller?.getLineStartOffset(line);
    if (offset != null) {
      _controller?.selection = TextSelection.collapsed(offset: offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }

    if (!_ready || _controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isMacOS = Platform.isMacOS;

    return CallbackShortcuts(
      bindings: {
        SingleActivator(
          LogicalKeyboardKey.keyS,
          control: !isMacOS,
          meta: isMacOS,
        ): _save,
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            Expanded(
              child: CodeForge(
                controller: _controller!,
                undoController: _undoController,
                language: _language ?? langJson,
                editorTheme: atomOneDarkTheme,
                textStyle: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14,
                ),
                enableFolding: true,
                enableGuideLines: true,
                filePath: widget.filePath,
              ),
            ),
            if (_diagnosticPanelVisible)
              _DiagnosticPanel(
                diagnostics: _diagnostics,
                initialHeight: _diagnosticPanelHeight,
                onHeightChanged: (h) => _diagnosticPanelHeight = h,
                onItemTap: _scrollToLine,
                onClose: () => setState(() => _diagnosticPanelVisible = false),
              ),
          ],
        ),
      ),
    );
  }
}

/// LSP 诊断信息底部面板
class _DiagnosticPanel extends StatefulWidget {
  final List<LspErrors> diagnostics;
  final double initialHeight;
  final ValueChanged<double> onHeightChanged;
  final ValueChanged<int> onItemTap;
  final VoidCallback onClose;

  const _DiagnosticPanel({
    required this.diagnostics,
    required this.initialHeight,
    required this.onHeightChanged,
    required this.onItemTap,
    required this.onClose,
  });

  @override
  State<_DiagnosticPanel> createState() => _DiagnosticPanelState();
}

class _DiagnosticPanelState extends State<_DiagnosticPanel> {
  late double _height;

  @override
  void initState() {
    super.initState();
    _height = widget.initialHeight;
  }

  @override
  void didUpdateWidget(_DiagnosticPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialHeight != widget.initialHeight) {
      _height = widget.initialHeight;
    }
  }

  Color _severityColor(int severity) {
    switch (severity) {
      case 1: // Error
        return Colors.red;
      case 2: // Warning
        return Colors.orange;
      case 3: // Info
        return Colors.blue;
      case 4: // Hint
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _severityIcon(int severity) {
    switch (severity) {
      case 1: // Error
        return Icons.error;
      case 2: // Warning
        return Icons.warning_amber;
      case 3: // Info
        return Icons.info_outline;
      case 4: // Hint
        return Icons.lightbulb_outline;
      default:
        return Icons.info_outline;
    }
  }

  void _onDrag(DragUpdateDetails details) {
    setState(() {
      _height = (_height - details.delta.dy).clamp(60.0, 400.0);
    });
  }

  void _onDragEnd(DragEndDetails _) {
    widget.onHeightChanged(_height);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: _height,
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        child: Column(
          children: [
            // 拖拽手柄 + 标题
            GestureDetector(
              onVerticalDragUpdate: _onDrag,
              onVerticalDragEnd: _onDragEnd,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: Row(
                  children: [
                    // 拖拽把手
                    Container(
                      width: 24,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 标题 + 数量统计
                    Text(
                      '诊断 (${widget.diagnostics.length})',
                      style: theme.textTheme.labelMedium,
                    ),
                    const Spacer(),
                    // 统计摘要
                    Text(
                      '${widget.diagnostics.where((d) => d.severity == 1).length}错误 '
                      '${widget.diagnostics.where((d) => d.severity == 2).length}警告',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 关闭按钮
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 诊断列表
            Expanded(
              child: widget.diagnostics.isEmpty
                  ? Center(
                      child: Text(
                        '没有诊断信息',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: widget.diagnostics.length,
                      itemBuilder: (context, index) {
                        final diag = widget.diagnostics[index];
                        final startLine =
                            (diag.range['start']?['line'] as int? ?? 0) + 1;
                        final color = _severityColor(diag.severity);

                        return InkWell(
                          onTap: () {
                            final line =
                                diag.range['start']?['line'] as int? ?? 0;
                            widget.onItemTap(line);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _severityIcon(diag.severity),
                                  size: 16,
                                  color: color,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '行 $startLine',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: color,
                                    fontFeatures: [
                                      const FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    diag.message,
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
