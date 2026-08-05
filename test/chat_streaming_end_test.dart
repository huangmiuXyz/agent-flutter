import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent/features/chat/widgets/chat_text_part.dart';
import 'package:agent/theme/app_theme.dart';
import 'package:agent/widgets/markdown/markdown_preview.dart';

/// 流式结束后文本渲染模式切换的回归测试。
///
/// 背景：part widget 实例缓存按 (part, streaming) 建键，streaming 在
/// Done/Error 后翻转但 part 实例不变 —— 若不把 streaming 纳入缓存键，
/// 流结束后的文本 part 会停留在流式增量渲染态（最后一行永远以纯文本
/// SelectableText 显示，markdown 围栏不再闭合）。
///
/// 同时覆盖：同一 element 在 streaming true↔false 间切换时 hook 顺序
/// 必须保持一致（flutter_hooks 在 debug 下会断言崩溃）。
void main() {
  const streamingContent = '第一行\n第二行';

  Future<void> pumpChatTextPart(
    WidgetTester tester, {
    required String content,
    required bool streaming,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: Scaffold(
          body: ChatTextPart(content: content, streaming: streaming),
        ),
      ),
    );
    // streamdown 订阅后重放缓冲内容需要一帧
    await tester.pump();
  }

  testWidgets('流式结束（streaming true→false）后切换到全量 markdown 渲染', (tester) async {
    // 流式中：完整行走 streamdown，未完成行走 SelectableText
    await pumpChatTextPart(
      tester,
      content: streamingContent,
      streaming: true,
    );
    expect(find.byType(MarkdownPreview), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget,
        reason: '流式期间未完成的最后一行应由 SelectableText 实时渲染');

    // 流结束：同一 content、仅 streaming 翻转 —— 不应崩溃，且应切回
    // 全量 markdown（不再有 SelectableText，最后一行也进入 markdown 渲染）
    await pumpChatTextPart(
      tester,
      content: streamingContent,
      streaming: false,
    );
    expect(find.byType(SelectableText), findsNothing,
        reason: '流结束后最后一行应合并进 markdown 全量渲染');
    expect(find.byType(MarkdownPreview), findsOneWidget);
    expect(find.textContaining('第二行'), findsWidgets,
        reason: '最后一行内容应完整渲染');
  });

  testWidgets('流式开始（streaming false→true）不应崩溃且增量渲染正确', (tester) async {
    await pumpChatTextPart(tester, content: '静态', streaming: false);
    expect(find.byType(MarkdownPreview), findsOneWidget);

    await pumpChatTextPart(tester, content: '静态\n增量', streaming: true);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(
      find.textContaining('增量'),
      findsWidgets,
      reason: '新进入流式的部分应以增量方式渲染',
    );
  });
}
