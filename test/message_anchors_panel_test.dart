import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent/features/chat/widgets/message_anchors_panel.dart';
import 'package:agent/theme/custom_theme.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData(extensions: [CustomTheme.light]),
  home: Scaffold(
    body: Center(
      // Align(topLeft) 给 loose 约束，模拟真实布局（Positioned 定位）：
      // 面板 Stack 宽度由竖条（22px）决定，而非被 tight 撑满
      child: SizedBox(
        width: 300,
        height: 600,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  ),
);

const _anchors = [
  UserAnchorData(msgId: 'm1', preview: '第一条消息', offset: 0, ratio: 0.1),
  UserAnchorData(msgId: 'm2', preview: '第二条消息', offset: 100, ratio: 0.5),
  UserAnchorData(msgId: 'm3', preview: '第三条消息', offset: 200, ratio: 0.9),
];

void main() {
  testWidgets('hover 竖条显示浮层，移入浮层保持，移出关闭', (tester) async {
    String? jumped;
    await tester.pumpWidget(
      _wrap(
        MessageAnchorsPanel(
          anchors: _anchors,
          activeMsgId: ValueNotifier<String?>('m1'),
          onJumpTo: (id) => jumped = id,
        ),
      ),
    );
    // 等 MaterialApp 路由入场转场完成（转场期间 AbsorbPointer 吸收指针）
    await tester.pump(const Duration(seconds: 1));

    final rect = tester.getRect(find.byType(MessageAnchorsPanel));
    // 面板 = 竖条（右缘 22px）+ 间隙 + 浮层（左缘 240px）
    final barCenter = Offset(rect.right - 11, rect.top + 300);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: barCenter);
    await tester.pump();

    // hover 竖条 → 浮层出现
    expect(find.text('第一条消息'), findsOneWidget);
    expect(find.text('第二条消息'), findsOneWidget);

    // 鼠标水平移入浮层（y 不变）→ 浮层保持不关闭（延迟计时器被取消）
    await mouse.moveTo(Offset(rect.left + 120, rect.top + 300));
    await tester.pump();
    expect(
      find.text('第二条消息'),
      findsOneWidget,
      reason: '鼠标移入浮层后面板不应关闭',
    );

    // 鼠标移出面板区域，等待延迟计时器 → 浮层关闭
    await mouse.moveTo(Offset(rect.left - 100, rect.top + 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('第一条消息'), findsNothing);

    // 重新 hover 竖条并点击浮层条目 → 触发跳转
    await mouse.moveTo(barCenter);
    await tester.pump();
    expect(find.text('第二条消息'), findsOneWidget);
    await mouse.moveTo(Offset(rect.left + 120, rect.top + 280));
    await tester.pump();
    await mouse.moveTo(Offset(rect.left + 120, rect.top + 280));
    await tester.pump();
    await mouse.down(Offset(rect.left + 120, rect.top + 280));
    await mouse.up();
    await tester.pump();
    expect(jumped, isNotNull);
  });

  testWidgets('hover 竖条顶部/底部边缘时移入浮层也不关闭', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MessageAnchorsPanel(
          anchors: _anchors,
          activeMsgId: ValueNotifier<String?>('m1'),
          onJumpTo: (_) {},
        ),
      ),
    );
    // 等 MaterialApp 路由入场转场完成（转场期间 AbsorbPointer 吸收指针）
    await tester.pump(const Duration(seconds: 1));

    final rect = tester.getRect(find.byType(MessageAnchorsPanel));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: Offset(rect.right - 11, rect.top + 4),
    );
    await tester.pump();
    expect(find.text('第一条消息'), findsOneWidget, reason: '竖条顶部 hover 出浮层');

    // 从顶部水平移入浮层：浮层应覆盖鼠标高度（top clamp 到 0）
    await mouse.moveTo(Offset(rect.left + 120, rect.top + 4));
    await tester.pump();
    expect(
      find.text('第一条消息'),
      findsOneWidget,
      reason: '顶部边缘移入浮层不应关闭',
    );

    // 底部边缘
    await mouse.moveTo(Offset(rect.right - 11, rect.top + 596));
    await tester.pump();
    expect(find.text('第三条消息'), findsOneWidget, reason: '竖条底部 hover 出浮层');
    await mouse.moveTo(Offset(rect.left + 120, rect.top + 596));
    await tester.pump();
    expect(
      find.text('第三条消息'),
      findsOneWidget,
      reason: '底部边缘移入浮层不应关闭',
    );
  });
}
