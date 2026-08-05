import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent/features/chat/widgets/chat_text_part.dart';
import 'package:agent/theme/app_theme.dart';
import 'package:agent/widgets/markdown/markdown_preview.dart';

/// 流式渲染回归测试。
///
/// 流式期间：完整行（带 `\n`）增量渲染；未完成行由 streamdown 的
/// tokenizer 缓冲，换行后才显示（不单独渲染「未完成行」）。
///
/// 同时覆盖：同一 element 在 streaming true↔false 间切换时 hook 顺序
/// 必须保持一致（flutter_hooks 在 debug 下会断言崩溃）。
void main() {
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
    await pumpChatTextPart(
      tester,
      content: '第一行\n第二行',
      streaming: true,
    );
    expect(find.byType(MarkdownPreview), findsOneWidget);
    expect(find.textContaining('第二行'), findsNothing,
        reason: '未完成行（无换行）由 tokenizer 缓冲，不单独渲染');

    // 流结束：同一 content、仅 streaming 翻转 —— 不应崩溃，且全量渲染
    await pumpChatTextPart(
      tester,
      content: '第一行\n第二行',
      streaming: false,
    );
    expect(find.byType(MarkdownPreview), findsOneWidget);
    expect(find.textContaining('第二行'), findsWidgets,
        reason: '流结束后最后一行应进入全量渲染');
  });

  testWidgets('流式开始（streaming false→true）不应崩溃且增量渲染正确', (tester) async {
    await pumpChatTextPart(tester, content: '静态', streaming: false);
    expect(find.byType(MarkdownPreview), findsOneWidget);

    await pumpChatTextPart(tester, content: '静态\n增量\n', streaming: true);
    expect(
      find.textContaining('增量'),
      findsWidgets,
      reason: '完整行应随到达立即渲染',
    );
  });

  testWidgets('流式期间完整行立即渲染、未完成行换行后才显示', (tester) async {
    await pumpChatTextPart(tester, content: '已完成行\n', streaming: true);
    expect(find.textContaining('已完成行'), findsWidgets);

    // 追加未完成行 → 缓冲，不显示
    await pumpChatTextPart(tester, content: '已完成行\n未完成', streaming: true);
    expect(find.textContaining('未完成'), findsNothing,
        reason: '未完成行不应渲染');

    // 换行后 → 成为完整行，立即显示
    await pumpChatTextPart(tester, content: '已完成行\n未完成\n', streaming: true);
    expect(find.textContaining('未完成'), findsWidgets);
  });

  testWidgets('第一条消息完成后再切回流式（第二条消息流式中），内容不应消失', (tester) async {
    const content = '第一条回复\n第二段\n';

    // 第一条消息流式中
    await pumpChatTextPart(tester, content: content, streaming: true);
    expect(find.textContaining('第一条回复'), findsWidgets);

    // 第一条消息流式结束（Done）→ 全量渲染
    await pumpChatTextPart(tester, content: content, streaming: false);
    expect(find.textContaining('第二段'), findsWidgets);

    // 第二条消息开始流式 → 整个会话 streaming=true，本条消息切回流式模式。
    // 复用了旧 controller（内容相同无增量），Streamdown 重建管线后重新
    // 订阅旧 stream —— 广播流不重放历史事件，内容会丢失。
    await pumpChatTextPart(tester, content: content, streaming: true);
    expect(find.textContaining('第一条回复'), findsWidgets,
        reason: '切回流式模式后内容不应消失');
    expect(find.textContaining('第二段'), findsWidgets,
        reason: '切回流式模式后已渲染内容应保持可见');
  });
}
