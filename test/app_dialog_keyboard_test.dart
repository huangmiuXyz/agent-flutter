import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/dialog/app_dialog.dart';
import 'package:agent/widgets/text/app_text.dart';

bool okCalled = false;
bool cancelCalled = false;

/// 打开弹窗并等待其出现，返回 show 的结果（异步）。
Future<void> openDialog(
  WidgetTester tester, {
  bool showFooter = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [CustomTheme.light]),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                await AppDialog.show(
                  context: context,
                  title: '标题',
                  child: const AppText('内容'),
                  showFooter: showFooter,
                  onOk: () => okCalled = true,
                  onCancel: () => cancelCalled = true,
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
  expect(find.text('内容'), findsOneWidget);
}

void main() {
  setUp(() {
    okCalled = false;
    cancelCalled = false;
  });

  testWidgets('回车键确认弹窗：触发 onOk 并关闭', (tester) async {
    await openDialog(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(okCalled, isTrue);
    expect(cancelCalled, isFalse);
    expect(find.text('内容'), findsNothing);
  });

  testWidgets('Esc 键取消弹窗：触发 onCancel 并关闭', (tester) async {
    await openDialog(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(cancelCalled, isTrue);
    expect(okCalled, isFalse);
    expect(find.text('内容'), findsNothing);
  });

  testWidgets('无 footer（无确认按钮）时回车不触发 onOk', (tester) async {
    await openDialog(tester, showFooter: false);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(okCalled, isFalse);
    expect(find.text('内容'), findsOneWidget);
  });
}
