import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent/features/chat/panels/chat_content.dart';
import 'package:agent/rust_bridge/api/types.dart' as api;
import 'package:agent/widgets/markdown/markdown_preview.dart';
import 'package:agent/services/session/part_types.dart';
import 'package:agent/services/session/session_state.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/app_theme.dart';

const sessionId = 'sess_repro';
const userMsgId = 'msg_user_1';
const assistantMsgId = 'msg_asst_1';

void main() {
  setUp(() {
    SessionStore.instance.sessions.value = {};
    SessionStore.instance.selectedId.value = null;
    SessionStore.instance.displayedSessionId.value = null;
    SessionStore.instance.streamingSessionIds.value = {};
  });

  tearDown(() {
    SessionStore.instance.unsubscribeSession(sessionId);
  });

  /// 模拟 switchTo 完成后的状态（DB 读不到 → 直接填充与 DB 相同的数据）
  void loadSessionLikeDb() {
    final s = SessionStore.instance.sessions.value[sessionId]!;
    s.loadFromMessages([
      api.MessageInfo(
        id: userMsgId,
        sessionId: sessionId,
        role: 'user',
        provider: '',
        model: '',
        createdAt: 0,
      ),
      api.MessageInfo(
        id: assistantMsgId,
        sessionId: sessionId,
        role: 'assistant',
        provider: 'openai',
        model: 'gpt-4o',
        createdAt: 0,
      ),
    ]);
    s.loadFromParts([
      api.PartInfo(
        id: 'part_user_text',
        msgId: userMsgId,
        seq: 0,
        partType: PartTypes.text,
        content: '{"content":"请帮我重构这个项目"}',
      ),
      api.PartInfo(
        id: 'part_asst_text',
        msgId: assistantMsgId,
        seq: 1,
        partType: PartTypes.text,
        content: '好的，我来重构。',
      ),
    ]);
  }

  Future<void> pumpChat(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: Scaffold(body: ChatContent()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('repro: 首次加载用户消息是否渲染为可编辑 Fleather', (tester) async {
    // 模拟 app 重启后第一次 switchTo
    SessionStore.instance.sessions.value = {
      sessionId: SessionState(sessionId),
    };
    loadSessionLikeDb();
    SessionStore.instance.displayedSessionId.value = sessionId;

    await pumpChat(tester);

    // 2 个 FleatherEditor：输入框 + 用户消息；用户消息应可编辑
    // （MarkdownPreview 只应有 1 个：assistant 消息）
    final fleather = find.byType(FleatherEditor);
    final markdown = find.byType(MarkdownPreview);
    // ignore: avoid_print
    print('首次加载: FleatherEditor=${fleather.evaluate().length} '
        'MarkdownPreview=${markdown.evaluate().length}');
    expect(
      fleather,
      findsNWidgets(2),
      reason: '输入框 + 用户消息各一个 FleatherEditor（user 角色）',
    );
    expect(markdown, findsOneWidget, reason: 'assistant 消息渲染为 Markdown');
  });

  testWidgets('repro: 重新 switchTo（模拟重新点击对话）', (tester) async {
    // 第一次加载
    SessionStore.instance.sessions.value = {
      sessionId: SessionState(sessionId),
    };
    loadSessionLikeDb();
    SessionStore.instance.displayedSessionId.value = sessionId;
    await pumpChat(tester);

    // 重新 switchTo 同一会话（不重建 SessionState，复用）
    await SessionStore.instance.switchTo(sessionId);
    await pumpChat(tester);

    final fleather = find.byType(FleatherEditor);
    expect(
      fleather,
      findsNWidgets(2),
      reason: '重新点击对话后用户消息仍为可编辑 Fleather',
    );
  });
}
