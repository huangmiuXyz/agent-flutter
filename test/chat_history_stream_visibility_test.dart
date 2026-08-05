import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent/features/chat/panels/chat_content.dart';
import 'package:agent/rust_bridge/api/types.dart' as api;
import 'package:agent/services/session/part_types.dart';
import 'package:agent/services/session/session_state.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/app_theme.dart';

/// 回归：第二条消息流式输出期间，第一条（历史）消息内容必须保持显示。
///
/// 曾出现的 bug：buildMessage 把会话级 isStreaming 传给所有历史消息，
/// 发送新消息时 streaming 翻转 → 历史消息切到流式模式，Streamdown
/// 重建管线后异步重放全文，产生 1-2 帧空白（发送时界面闪烁）。
void main() {
  const sessionId = 'vis_session';

  setUp(() {
    SessionStore.instance.sessions.value = {};
    SessionStore.instance.selectedId.value = null;
    SessionStore.instance.displayedSessionId.value = null;
    SessionStore.instance.streamingSessionIds.value = {};
  });

  tearDown(() {
    SessionStore.instance.unsubscribeSession(sessionId);
  });

  testWidgets('第二条消息流式中，第一条消息内容保持显示', (tester) async {
    final s = SessionState(sessionId);
    const user1 = 'u1';
    const asst1 = 'a1';
    const user2 = 'u2';
    const asst2 = 'a2';
    s.messageOrder.addAll([user1, asst1, user2, asst2]);
    s.messageRoles[user1] = 'user';
    s.messageRoles[asst1] = 'assistant';
    s.messageRoles[user2] = 'user';
    s.messageRoles[asst2] = 'assistant';
    s.partsByMsg[user1] = [
      api.PartInfo(
        id: '${user1}_p',
        msgId: user1,
        seq: 0,
        partType: PartTypes.text,
        content: '第一条用户消息',
      ),
    ];
    s.partsByMsg[asst1] = [
      api.PartInfo(
        id: '${asst1}_p',
        msgId: asst1,
        seq: 0,
        partType: PartTypes.text,
        content: '第一条回复\n',
      ),
    ];
    s.partsByMsg[user2] = [
      api.PartInfo(
        id: '${user2}_p',
        msgId: user2,
        seq: 0,
        partType: PartTypes.text,
        content: '第二条用户消息',
      ),
    ];
    s.partsByMsg[asst2] = [
      api.PartInfo(
        id: '${asst2}_p',
        msgId: asst2,
        seq: 0,
        partType: PartTypes.text,
        content: '第二条回复\n',
      ),
    ];

    SessionStore.instance.sessions.value = {sessionId: s};
    SessionStore.instance.streamingSessionIds.value = {sessionId};
    SessionStore.instance.displayedSessionId.value = sessionId;
    SessionStore.instance.selectedId.value = sessionId;

    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: Scaffold(body: ChatContent()),
      ),
    );
    await tester.pump();
    await tester.pump();

    // 第一条历史消息必须可见（静态渲染，不随 streaming 翻转重建）
    expect(find.textContaining('第一条回复'), findsWidgets,
        reason: '第二条流式期间，第一条回复不应消失');
    // 正在流式的第二条回复应渲染（异步重放需一帧）
    expect(find.textContaining('第二条回复'), findsWidgets);
  });
}
