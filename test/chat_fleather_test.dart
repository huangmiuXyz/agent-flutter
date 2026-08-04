import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent/features/chat/chat_fleather.dart';
import 'package:agent/theme/app_theme.dart';
import 'package:agent/utils/ime_composing_tracker.dart';

void main() {
  Future<void> pumpChatFleather(
    WidgetTester tester, {
    required VoidCallback onSubmit,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 200,
            child: ChatFleather(onSubmit: onSubmit),
          ),
        ),
      ),
    );
    // 点击编辑器获得焦点并建立文本输入连接
    await tester.tap(find.byType(FleatherEditor));
    await tester.pumpAndSettle();
  }

  /// 模拟引擎推送的 IME 组合 delta 消息（composing 区域有效）。
  void simulateComposing(WidgetTester tester) {
    ImeComposingTracker.instance.handleEngineMessage(
      const MethodCall(
        'TextInputClient.updateEditingStateWithDeltas',
        <dynamic>[
          1,
          <String, dynamic>{
            'deltas': <Map<String, dynamic>>[
              {
                'oldText': '',
                'deltaText': 'nihao',
                'deltaStart': 0,
                'deltaEnd': 0,
                'selectionBase': 5,
                'selectionExtent': 5,
                'selectionAffinity': 'TextAffinity.downstream',
                'selectionIsDirectional': false,
                'composingBase': 0,
                'composingExtent': 5,
              },
            ],
          },
        ],
      ),
    );
  }

  /// 模拟引擎推送的组合提交消息（composing 区域清空）。
  void simulateCompositionCommitted(WidgetTester tester) {
    ImeComposingTracker.instance.handleEngineMessage(
      const MethodCall(
        'TextInputClient.updateEditingStateWithDeltas',
        <dynamic>[
          1,
          <String, dynamic>{
            'deltas': <Map<String, dynamic>>[
              {
                'oldText': 'nihao',
                'deltaText': 'nihao',
                'deltaStart': 0,
                'deltaEnd': 0,
                'selectionBase': 5,
                'selectionExtent': 5,
                'selectionAffinity': 'TextAffinity.downstream',
                'selectionIsDirectional': false,
                'composingBase': -1,
                'composingExtent': -1,
              },
            ],
          },
        ],
      ),
    );
  }

  setUp(() {
    // 与 main() 一致：安装通道监听与焦点切换重置
    ImeComposingTracker.instance.install();
    ImeComposingTracker.instance.reset();
  });

  testWidgets('无输入法组合时按 Enter 触发发送', (tester) async {
    var submitted = 0;
    await pumpChatFleather(tester, onSubmit: () => submitted++);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(submitted, 1);
  });

  testWidgets('输入法组合中按 Enter 不发送，让组合内容落下', (tester) async {
    var submitted = 0;
    await pumpChatFleather(tester, onSubmit: () => submitted++);

    // 模拟输入法组合状态（如拼音输入 "nihao" 候选阶段）
    simulateComposing(tester);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(submitted, 0);
  });

  testWidgets('组合提交后按 Enter 触发发送', (tester) async {
    var submitted = 0;
    await pumpChatFleather(tester, onSubmit: () => submitted++);

    // 组合中第一次 Enter：只提交组合，不发送
    simulateComposing(tester);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(submitted, 0);

    // 组合结束（IME 推送提交后的状态）
    simulateCompositionCommitted(tester);
    await tester.pump();

    // 第二次 Enter：正常发送
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(submitted, 1);
  });

  testWidgets('Shift+Enter 不触发发送', (tester) async {
    var submitted = 0;
    await pumpChatFleather(tester, onSubmit: () => submitted++);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(submitted, 0);
  });

  testWidgets('焦点切换到其他输入框后组合状态被重置，切回后按 Enter 可发送', (tester) async {
    var submitted = 0;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                width: 600,
                height: 200,
                child: ChatFleather(
                  focusNode: focusNode,
                  onSubmit: () => submitted++,
                ),
              ),
              // 另一个可聚焦输入框（模拟输入框间焦点切换）
              const TextField(),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(FleatherEditor));
    await tester.pumpAndSettle();

    simulateComposing(tester);
    await tester.pump();
    expect(ImeComposingTracker.instance.isComposing, isTrue);

    // 焦点切换到另一个输入框 → 组合状态重置
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(ImeComposingTracker.instance.isComposing, isFalse);

    // 切回聊天输入框后按 Enter 正常发送
    await tester.tap(find.byType(FleatherEditor));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(submitted, 1);
  });
}
