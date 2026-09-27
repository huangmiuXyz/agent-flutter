import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent/features/chat/widgets/message_anchors_panel.dart';
import 'package:agent/theme/custom_theme.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData(extensions: [CustomTheme.light]),
  home: Scaffold(
    body: Center(
      // 给定一个高 600、宽 300 的可用区域，模拟聊天区悬停浮层动画的基座。
      // 面板应只占据内容(几条横线)本身的高度，而不是填满整个 600。
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
  // 默认测试平台是 Android，会走手机分支（点击展开而非 hover）。
  // 每个测试内显式用桌面平台验证 hover，并在测试体的最末尾复位
  //（flutter_test 在每个测试结束时校验 foundation 调试变量未被改动）。
  void useDesktop() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  }

  void resetPlatform() {
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets('面板高度贴合内容，不占满整个聊天区高度', (tester) async {
    useDesktop();
    await tester.pumpWidget(
      _wrap(
        MessageAnchorsPanel(
          anchors: _anchors,
          activeMsgId: ValueNotifier<String?>('m1'),
          onJumpTo: (_) {},
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    final rect = tester.getRect(find.byType(MessageAnchorsPanel));

    // 核心断言：面板高度约等于 行数*行高 + 上下内边距，而不是聊天区全高 600
    expect(rect.height, greaterThan(0));
    expect(rect.height, lessThan(300), reason: '面板不应超过可用高度的一半');
    expect(rect.height, lessThan(600), reason: '面板不应占满整个聊天区高度');
    // 3 行 * 24 + 上下 padding 20 ≈ 92
    expect(rect.height, closeTo(3 * 24 + 20, 2));

    // 未展开时是窄条
    expect(rect.width, lessThan(40), reason: '未展开时面板应是窄条');

    resetPlatform();
  });

  testWidgets('手机：点击右侧整条区域可展开/收起面板', (tester) async {
    // 不设置平台覆盖 → 默认 Android，走手机分支
    await tester.pumpWidget(
      _wrap(
        MessageAnchorsPanel(
          anchors: _anchors,
          activeMsgId: ValueNotifier<String?>('m1'),
          onJumpTo: (_) {},
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // 收起状态：窄条，点击热区覆盖聊天区全高
    final closed = tester.getRect(find.byType(MessageAnchorsPanel));
    expect(closed.width, lessThan(40), reason: '收起时是窄条');
    expect(closed.height, greaterThan(500), reason: '点击热区覆盖全高');

    // 点击窄条区域中点：收起态下行不可命中，点击应直接触发热区弹出面板
    final g = await tester.startGesture(closed.center);
    await tester.pump(const Duration(milliseconds: 50));
    await g.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 展开成面板并显示预览文字
    expect(
      tester.getRect(find.byType(MessageAnchorsPanel)).width,
      greaterThan(200),
      reason: '点击后应展开成面板',
    );

    // 再次点击关闭
    final opened = tester.getRect(find.byType(MessageAnchorsPanel));
    await tester.tapAt(opened.center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.getRect(find.byType(MessageAnchorsPanel)).width,
      lessThan(40),
      reason: '再次点击应收起',
    );

    resetPlatform();
  });

  testWidgets('hover 竖条展开并显示文字，点击条目跳转', (tester) async {
    useDesktop();
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

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    // 初始为窄条，悬停到竖条内部（右缘附近、中部）
    final initial = tester.getRect(find.byType(MessageAnchorsPanel));
    await mouse.addPointer(
      location: Offset(initial.right - 4, initial.top + 40),
    );
    await tester.pump();
    // 等宽度展开动画（140ms）完成
    await tester.pump(const Duration(milliseconds: 200));

    // 展开后显示每条预览文字
    expect(find.text('第一条消息'), findsOneWidget);
    expect(find.text('第二条消息'), findsOneWidget);
    expect(find.text('第三条消息'), findsOneWidget);

    // 面板展开变宽（240）
    final rect = tester.getRect(find.byType(MessageAnchorsPanel));
    expect(rect.width, greaterThan(200), reason: 'hover 后应横向展开');

    // 点击某行 → 触发跳转
    final secondItemY = rect.top + 10 + 24 + 12; // 第二条所在 y
    await mouse.moveTo(Offset(rect.left + 50, secondItemY));
    await tester.pump();
    await mouse.down(Offset(rect.left + 50, secondItemY));
    await mouse.up();
    await tester.pump();
    expect(jumped, 'm2');

    // 移出面板，延迟后收起
    await mouse.moveTo(Offset(rect.left - 100, secondItemY));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.getRect(find.byType(MessageAnchorsPanel)).width,
      lessThan(40),
      reason: '移出后面板应收起为窄条',
    );

    resetPlatform();
  });
}