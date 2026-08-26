/// 移动端 app 内编辑器页 — 全屏路由 `/editor`（覆盖底部壳，带返回）。
///
/// 复用 EditorWindow（code_forge）；文件切换跟随 CodeForgeStore，
/// openFile 在移动端直接跳转到本路由。
library;

import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:agent/features/editor/editor_window.dart';
import 'package:agent/store/code_forge_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/text/app_text.dart';

class EditorPage extends StatelessWidget {
  const EditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final path = CodeForgeStore.instance.filePath.value;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: custom.colors.panel,
        surfaceTintColor: Colors.transparent,
        title: SignalBuilder(
          builder: (_) {
            final current = CodeForgeStore.instance.filePath.value;
            final name = current.split('/').last;
            return AppText(
              name.isEmpty ? '编辑' : '编辑 — $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            );
          },
        ),
      ),
      // EditorWindow 自身监听 CodeForgeStore 的文件切换（effect），
      // 这里只在首次构建时传入初始路径，路径变化不重建整个编辑器
      body: EditorWindow(filePath: path),
    );
  }
}
