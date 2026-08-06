import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent/features/chat/panels/chat_content.dart';
import 'package:agent/features/chat/widgets/chat_message_item.dart';
import 'package:agent/rust_bridge/api/types.dart' as api;
import 'package:agent/services/session/part_types.dart';
import 'package:agent/services/session/session_state.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/app_theme.dart';

/// 短会话顶部对齐测试。
///
/// reverse 列表默认贴底：新会话只有少量消息时内容会悬在视口底部
/// （输入框正上方），上方大片空白，视觉别扭。修复：内容项不超过
/// [_topAlignedMaxItems] 时列表 shrinkWrap（高度=内容高度），
/// 外层 Align(topCenter) 因此把内容顶对齐、向下生长；
/// 超过阈值后内容必然超出一屏，切回虚拟化 reverse 贴底。
void main() {
  const sessionId = 'top_align_session';

  /// 构造会话：消息按 [buildMsg] 构造，共 [total] 条。
  SessionState buildSession(
    int total, {
    required String Function(int i) content,
  }) {
    final s = SessionState(sessionId);
    for (int i = 0; i < total; i++) {
      final msgId = '${sessionId}_msg_$i';
      s.messageOrder.add(msgId);
      s.messageRoles[msgId] = i.isEven ? 'user' : 'assistant';
      s.partsByMsg[msgId] = [
        api.PartInfo(
          id: '${msgId}_p0',
          msgId: msgId,
          seq: 0,
          partType: PartTypes.text,
          content: content(i),
        ),
      ];
    }
    return s;
  }

  Future<void> openSession(WidgetTester tester, SessionState s) async {
    SessionStore.instance.sessions.value = {sessionId: s};
    await SessionStore.instance.switchTo(sessionId);
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: Scaffold(body: ChatContent()),
      ),
    );
    // Fleather 编辑器等异步收敛
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  setUp(() {
    SessionStore.instance.sessions.value = {};
    SessionStore.instance.selectedId.value = null;
    SessionStore.instance.displayedSessionId.value = null;
    SessionStore.instance.streamingSessionIds.value = {};
  });

  /// 读取消息列表当前帧的滚动位置（reverse 列表贴底 = pixels == 0）
  double pixels(WidgetTester tester) {
    final listView = find.byType(ListView).first;
    final pos = tester
        .state<ScrollableState>(
          find.descendant(of: listView, matching: find.byType(Scrollable)).first,
        )
        .position;
    return pos.pixels;
  }

  testWidgets('短会话（新会话几条消息）：内容从视口顶部开始，不悬在底部', (tester) async {
    // 2 条短消息（1 用户 + 1 assistant），远小于阈值，必不足一屏
    await openSession(
      tester,
      buildSession(2, content: (i) => '第 $i 条消息'),
    );

    final listView = tester.widget<ListView>(find.byType(ListView).first);
    expect(listView.shrinkWrap, isTrue,
        reason: '短会话应 shrinkWrap：列表高度=内容高度，配合 Align 顶对齐');

    final listTop = tester.getTopLeft(find.byType(ListView).first).dy;
    final listHeight = tester.getSize(find.byType(ListView).first).height;
    // 首条消息（用户消息由 Fleather 编辑器渲染，find.text 不可见，
    // 改用 ChatMessageItem 定位；reverse 列表树序最新在前，
    // 视觉顶部的最旧消息是 .last）应在视口顶部区域，而不是悬在底部
    final firstItemTop = tester
        .getTopLeft(find.byType(ChatMessageItem).last)
        .dy;
    expect(firstItemTop - listTop, lessThan(listHeight * 0.3),
        reason: '短会话首条消息应位于视口顶部区域（修复前会悬在底部）');
    // 阅读顺序不变：用户消息在上、assistant 回复在下
    final lastMsgTop = tester.getTopLeft(find.text('第 1 条消息')).dy;
    expect(lastMsgTop, greaterThan(firstItemTop));
    expect(tester.takeException(), isNull);

    // 消化 Fleather 内部的 history 合并 timer（500ms）
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('长会话：仍为虚拟化 reverse 贴底（shrinkWrap=false）', (tester) async {
    // 300 条消息远超阈值，内容必超出一屏
    await openSession(
      tester,
      buildSession(300, content: (i) => '第 $i 条消息'),
    );

    final listView = tester.widget<ListView>(find.byType(ListView).first);
    expect(listView.shrinkWrap, isFalse,
        reason: '长会话应保持虚拟化（非 shrinkWrap），避免全量构建');

    // 贴底：首帧显示最后一条消息，滚动位置 offset 0
    expect(find.text('第 299 条消息'), findsOneWidget,
        reason: 'reverse 列表初始即显示最新内容');
    expect(pixels(tester), 0, reason: 'reverse 列表初始 offset 0 = 底部');
    // 虚拟滚动仍生效：视口外的早期消息不得构建
    expect(find.text('第 0 条消息'), findsNothing,
        reason: '视口外 item 不得构建（虚拟滚动）');
    expect(tester.takeException(), isNull);

    // 消化 Fleather 内部的 history 合并 timer（500ms）
    await tester.pump(const Duration(milliseconds: 600));
  });
}
