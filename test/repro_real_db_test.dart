import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent/features/chat/panels/chat_content.dart';
import 'package:agent/rust_bridge/api/messages.dart' as msg_api;
import 'package:agent/rust_bridge/frb_generated.dart' as frb;
import 'package:agent/services/session/session_state.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/app_theme.dart';
import 'package:agent/widgets/markdown/markdown_preview.dart';

/// 使用真实 Rust 后端 + 真实 DB 复现「重启后首次加载」行为。
/// 需要 macOS 本机编译好的 rust_lib_agent dylib（flutter test 宿主进程加载）。
void main() {
  const sessionId = 'ses_1785895331132';
  const dbPath =
      '/Users/Zhuanz/obj/private/agent-flutter-cli/data/data';

  setUpAll(() async {
    await frb.RustLib.init();
  });

  setUp(() {
    SessionStore.instance.sessions.value = {};
    SessionStore.instance.selectedId.value = null;
    SessionStore.instance.displayedSessionId.value = null;
    SessionStore.instance.streamingSessionIds.value = {};
    // dbPath 由 _resolveDbPath() 自动解析：测试 CWD 在 agent/ 下 →
    // 指向 ../agent-flutter-cli/data/data（真实 DB）
  });

  tearDown(() {
    SessionStore.instance.unsubscribeSession(sessionId);
  });

  testWidgets('真实 DB：switchTo 首次加载后用户消息应为可编辑 Fleather', (tester) async {
    // 直接验证 Rust API 是否可用（诊断环境）
    final msgs = await msg_api.listMessagesBySession(
      dbPath: dbPath,
      sessionId: sessionId,
    );
    // ignore: avoid_print
    print('[DBG] real listMessages -> ${msgs.length} msgs, '
        'roles=${msgs.map((m) => '${m.id}:${m.role}').join(', ')}');

    await SessionStore.instance.switchTo(sessionId);
    // ignore: avoid_print
    print('[DBG] after switchTo sessions=${SessionStore.instance.sessions.value.keys} '
        'order=${SessionStore.instance.stateFor(sessionId)?.messageOrder} '
        'roles=${SessionStore.instance.stateFor(sessionId)?.messageRoles}');

    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: Scaffold(body: ChatContent()),
      ),
    );
    await tester.pump();
    await tester.pump();

    final fleather = find.byType(FleatherEditor);
    final markdown = find.byType(MarkdownPreview);
    // ignore: avoid_print
    print('[DBG] FleatherEditor=${fleather.evaluate().length} '
        'MarkdownPreview=${markdown.evaluate().length}');
    expect(
      fleather.evaluate().length,
      greaterThanOrEqualTo(1),
      reason: '用户消息应渲染为可编辑 Fleather',
    );
  });
}
