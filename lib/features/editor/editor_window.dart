/// 编辑器子窗口 — 使用 code_forge 编辑任意文本文件。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:code_forge/code_forge.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

/// 在子窗口中打开一个文件进行编辑。
class EditorWindow extends StatefulWidget {
  final String filePath;
  const EditorWindow({super.key, required this.filePath});

  @override
  State<EditorWindow> createState() => _EditorWindowState();
}

class _EditorWindowState extends State<EditorWindow> {
  late final CodeForgeController _controller;
  late final UndoRedoController _undoController;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _undoController = UndoRedoController();
    _initAndOpen();
  }

  Future<void> _initAndOpen() async {
    // 先初始化 RustLib，再创建 Controller
    try {
      final dylib = '${Platform.environment['HOME']}'
          '/.pub-cache/hosted/pub.dev/code_forge-10.8.0/rust/target/release/libcode_forge.dylib';
      if (File(dylib).existsSync()) {
        final lib = ExternalLibrary.open(dylib);
        await RustLib.init(externalLibrary: lib);
      }
    } catch (e) {
      debugPrint('code_forge init: $e');
    }
    _controller = CodeForgeController();
    _controller.text = _readFile();
    // 延迟添加 listener，避免 CodeForge initState 触发 change 时还在 build 阶段
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.addListener(_onChanged);
    });
    if (mounted) setState(() => _ready = true);
  }

  String _readFile() {
    final file = File(widget.filePath);
    return file.existsSync() ? file.readAsStringSync() : '';
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _undoController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!_dirty && mounted) {
      _dirty = true;
      setState(() {});
    }
  }

  bool _dirty = false;
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await File(widget.filePath).writeAsString(_controller.text);
      setState(() => _dirty = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filename = widget.filePath.split('/').last;
    final dir = Directory(widget.filePath).parent.path;
    final isMacOS = Platform.isMacOS;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(filename, style: const TextStyle(fontSize: 14)),
            Text(
              dir,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (_dirty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '未保存',
                style: TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            tooltip: '保存 (${isMacOS ? "⌘" : "Ctrl"}S)',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: CallbackShortcuts(
        bindings: {
          SingleActivator(
            LogicalKeyboardKey.keyS,
            control: !isMacOS,
            meta: isMacOS,
          ): _save,
        },
        child: Focus(
          autofocus: true,
          child: !_ready
              ? const Center(child: CircularProgressIndicator())
              : CodeForge(
                  controller: _controller,
                  undoController: _undoController,
                  language: langJson,
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
      ),
    );
  }
}
