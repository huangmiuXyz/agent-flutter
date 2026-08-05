import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent/features/chat/panels/chat_content.dart';
import 'package:agent/rust_bridge/api/types.dart' as api;
import 'package:agent/services/session/part_types.dart';
import 'package:agent/services/session/session_state.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/app_theme.dart';

/// 切换会话时消息列表的「弹跳」复现测试。
///
/// 逐帧记录列表可见性（Opacity）与滚动位置，验证：
/// - 列表在全部 jumpTo 收敛完成前保持隐藏（opacity == 0）
/// - 首次可见的那一帧就已位于底部，之后不再跳位（extentAfter 保持 ~0）
///
/// 构造会话时让消息高度高度不均匀（前几条极短、其余极长），使
/// ListView 懒加载的 maxScrollExtent 估算值与真实值偏差巨大 ——
/// 这正是真实会话（工具卡片/代码块/短文本混排）里弹跳的来源。
void main() {
  const sessionA = 'session_a';
  const sessionB = 'session_b';

  /// 构造消息高度不均匀的会话：前 [shortCount] 条是单行短文本，
  /// 其余是 30 行长文本（每条约 450px+），估算值会严重偏低。
  SessionState _buildSession(String id, {int shortCount = 10, int total = 300}) {
    final s = SessionState(id);
    for (int i = 0; i < total; i++) {
      final msgId = '${id}_msg_$i';
      final isShort = i < shortCount;
      s.messageOrder.add(msgId);
      s.messageRoles[msgId] = i.isEven ? 'user' : 'assistant';
      s.partsByMsg[msgId] = [
        api.PartInfo(
          id: '${msgId}_p0',
          msgId: msgId,
          seq: 0,
          partType: PartTypes.text,
          content: isShort ? '短消息 $i' : '第 $i 条长消息\n${'内容行\n' * 30}',
        ),
      ];
    }
    return s;
  }

  /// 读取消息列表当前帧的 (opacity, pixels, maxScrollExtent, extentAfter)
  (double, double, double, double) _listState(WidgetTester tester) {
    final listView = find.byType(ListView).first;
    final opacity = tester
        .widget<Opacity>(
          find.ancestor(of: listView, matching: find.byType(Opacity)).first,
        )
        .opacity;
    final pos = tester
        .state<ScrollableState>(
          find.descendant(of: listView, matching: find.byType(Scrollable)).first,
        )
        .position;
    return (opacity, pos.pixels, pos.maxScrollExtent, pos.extentAfter);
  }

  testWidgets('切换会话：列表收敛前隐藏，首次可见即位于底部且不再跳位', (tester) async {
    SessionStore.instance.sessions.value = {
      sessionA: _buildSession(sessionA),
      sessionB: _buildSession(sessionB),
    };
    SessionStore.instance.displayedSessionId.value = sessionA;
    SessionStore.instance.selectedId.value = sessionA;

    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: Scaffold(body: ChatContent()),
      ),
    );
    await tester.pump(); // 首帧 + 切换 effect 的 postFrame（jumpTo）
    await tester.pump(); // 收敛完成

    // 切换到会话 B，逐帧记录
    final frames = <String>[];
    final visibleFrames = <int>[];
    double? firstVisiblePx;
    for (int i = 0; i < 8; i++) {
      await tester.pump();
      final (opacity, px, max, extentAfter) = _listState(tester);
      final visible = opacity > 0.5;
      if (visible) {
        visibleFrames.add(i);
        firstVisiblePx ??= px;
      }
      frames.add(
        'frame$i: opacity=${opacity.toStringAsFixed(1)} '
        'px=${px.toStringAsFixed(0)} max=${max.toStringAsFixed(0)} '
        'extentAfter=${extentAfter.toStringAsFixed(1)}',
      );
    }
    // ignore: avoid_print
    print('=== 切换会话逐帧 ===\n${frames.join('\n')}');

    // 1. 首次可见之前列表必须保持隐藏（全部 jumpTo 在隐藏期间完成）
    expect(visibleFrames, isNotEmpty);
    final firstVisible = visibleFrames.first;
    for (int i = 0; i < firstVisible; i++) {
      expect(frames[i].startsWith('frame$i: opacity=0.0'), isTrue,
          reason: '收敛完成前列表必须保持隐藏');
    }
    // 2. 首次可见的那一帧已经收敛到真实底部
    expect(firstVisiblePx, isNotNull);
    final (op0, px0, max0, after0) = _listState(tester);
    expect(after0, lessThan(1),
        reason: '列表首次可见时应在真实底部（extentAfter≈0）');
    // 3. 可见后的所有帧不再跳位
    for (int i = firstVisible + 1; i < frames.length; i++) {
      await tester.pump();
      final (opacity, px, _, extentAfter) = _listState(tester);
      expect(opacity, greaterThan(0.5), reason: '显示后不应再隐藏');
      expect(extentAfter, lessThan(1),
          reason: '可见期间滚动位置不应再变化（弹跳）');
      expect(px, closeTo(firstVisiblePx!, 1), reason: '可见期间 px 不应跳变');
    }
  });
}
