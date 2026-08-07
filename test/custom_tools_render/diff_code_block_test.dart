import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent/features/chat/custom_tools_render/chat_diff_block.dart';
import 'package:agent/features/chat/custom_tools_render/diff_code_block.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/text/virtual_paragraph_text.dart';

/// 测试宿主：提供主题扩展与固定宽度、松高度约束
/// （对齐消息列表项的真实上下文：宽度紧、高度由内容决定）
Widget wrap(Widget child) => MaterialApp(
  theme: ThemeData(extensions: [CustomTheme.light]),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 400, child: child),
    ),
  ),
);

/// 构造 n 条内容行的补丁（1 个文件头 + n 个新增行）
String patchLines(int n) {
  final b = StringBuffer('*** Begin Patch\n*** Update File: lib/a.dart\n@@\n');
  for (var i = 0; i < n; i++) {
    b.write('+void f$i() {}\n');
  }
  b.write('*** End Patch\n');
  return b.toString();
}

/// JSON 字符串值的转义形式（不带包裹引号），模拟 Rust 端 arguments 的原始文本
String esc(String s) {
  final e = jsonEncode(s);
  return e.substring(1, e.length - 1);
}

void main() {
  // 短 diff：自然高度，一次构建全部行，无内部滚动
  testWidgets('短 diff 自然高度渲染全部行', (tester) async {
    await tester.pumpWidget(wrap(DiffCodeBlock(diff: patchLines(5))));

    expect(find.byType(ListView), findsNothing);
    // 5 行内容（内容行是 SelectableText；文件头/信封行不是）
    expect(find.byType(SelectableText), findsNWidgets(5));
    // 高度 = 文件头 30 + 5×18 = 120
    expect(tester.getSize(find.byType(DiffCodeBlock)).height, 120);
    expect(find.text('void f0() {}'), findsOneWidget);
    expect(find.text('void f4() {}'), findsOneWidget);
  });

  // 大 diff：超过 chatPartExpandedMaxHeight 封顶，虚拟滚动只构建可见行
  testWidgets('大 diff 封顶虚拟滚动', (tester) async {
    await tester.pumpWidget(wrap(DiffCodeBlock(diff: patchLines(100))));

    final listView = find.byType(ListView);
    expect(listView, findsOneWidget);
    // 封顶高度 = 主题 token chatPartExpandedMaxHeight = 320
    expect(tester.getSize(listView).height, 320);
    // 只构建可见行 + cacheExtent（远少于 100 行）
    expect(find.byType(SelectableText).evaluate().length, lessThan(50));
    // 首行可见
    expect(find.text('void f0() {}'), findsOneWidget);
    // 末行未构建（虚拟化），滚动后可见
    expect(find.text('void f99() {}'), findsNothing);
    await tester.drag(listView, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('void f99() {}'), findsOneWidget);
  });

  // 流式追加：短 → 长 时从自然高度切换为虚拟滚动，状态无缝延续
  testWidgets('流式追加切换虚拟滚动', (tester) async {
    await tester.pumpWidget(wrap(DiffCodeBlock(diff: patchLines(10))));
    expect(find.byType(ListView), findsNothing);

    await tester.pumpWidget(wrap(DiffCodeBlock(diff: patchLines(100))));
    final listView = find.byType(ListView);
    expect(listView, findsOneWidget);
    expect(tester.getSize(listView).height, 320);
    expect(find.text('void f0() {}'), findsOneWidget);
  });

  // 工具调用参数流式：半截 JSON 逐 chunk 增量渲染
  testWidgets('arguments 流式增量渲染', (tester) async {
    final prefix =
        '*** Begin Patch\n*** Update File: lib/a.dart\n@@\n+void a() {}\n';
    final full = '$prefix+void b() {}\n+void c() {}\n*** End Patch\n';

    await tester.pumpWidget(
      wrap(
        ChatDiffBlock.arguments(
          rawArguments: '{"patch": "${esc(prefix)}"',
        ),
      ),
    );
    expect(find.text('void a() {}'), findsOneWidget);
    expect(find.text('void b() {}'), findsNothing);

    // 前缀追加的完成态 arguments
    await tester.pumpWidget(
      wrap(
        ChatDiffBlock.arguments(
          rawArguments: '{"patch": "${esc(full)}"}',
        ),
      ),
    );
    expect(find.text('void a() {}'), findsOneWidget);
    expect(find.text('void b() {}'), findsOneWidget);
    expect(find.text('void c() {}'), findsOneWidget);
  });

  // 历史加载：完整合法 JSON 直接读键（含引号的补丁不被截断）
  testWidgets('完成态直接读键含引号不截断', (tester) async {
    final patch = patchLines(3).replaceAll('void f0', 'void "f0"');
    await tester.pumpWidget(
      wrap(
        ChatDiffBlock.arguments(
          rawArguments: '{"patch": "${esc(patch)}"}',
        ),
      ),
    );
    expect(find.text('void "f0"() {}'), findsOneWidget);
    expect(find.text('void f2() {}'), findsOneWidget);
  });

  // ── 滚动接续：内层封顶滚动区（diff/思考/工具结果）滚到边界后，
  // 由外层消息列表接管 ──

  /// 外层可滚动宿主：0 高占位 + 内层（封顶 320）+ 高占位
  Widget chainHarness(ScrollController outer, Widget inner) => MaterialApp(
    theme: ThemeData(extensions: [CustomTheme.light]),
    home: Scaffold(
      body: ListView.builder(
        controller: outer,
        itemCount: 3,
        itemBuilder: (context, index) => switch (index) {
          0 => const SizedBox.shrink(),
          1 => SizedBox(height: 320, child: inner),
          _ => const SizedBox(height: 800),
        },
      ),
    ),
  );

  /// 内层滚动容器的 position（外层 ListView 之后的第一个 Scrollable）
  ScrollPosition innerPosition(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView).at(1),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;

  testWidgets('内层滚到底后继续拖动由外层接管', (tester) async {
    final outer = ScrollController();
    addTearDown(outer.dispose);
    await tester.pumpWidget(
      chainHarness(outer, DiffCodeBlock(diff: patchLines(30))),
    );

    final inner = find.byType(ListView).at(1);
    // 内层总高 30×18+30=570，封顶 320 → 滚动范围 250；
    // 分帧拖 400：250 归内层，余量逐帧转给外层
    await tester.timedDrag(inner, const Offset(0, -400), const Duration(milliseconds: 300));
    await tester.pump();

    final innerPos = innerPosition(tester);
    expect(innerPos.pixels, closeTo(innerPos.maxScrollExtent, 1));
    final before = outer.position.pixels;
    expect(before, greaterThan(0)); // 第一次拖动已有部分转给外层

    // 内层已在底部，继续拖动 → 外层接管滚动
    await tester.timedDrag(inner, const Offset(0, -100), const Duration(milliseconds: 100));
    await tester.pump();
    expect(outer.position.pixels, greaterThan(before));
    // 内层仍停在底部
    expect(innerPos.pixels, closeTo(innerPos.maxScrollExtent, 1));
  });

  testWidgets('内层滚到顶后继续上拖由外层接管', (tester) async {
    final outer = ScrollController();
    addTearDown(outer.dispose);
    await tester.pumpWidget(
      chainHarness(outer, DiffCodeBlock(diff: patchLines(30))),
    );

    final inner = find.byType(ListView).at(1);
    // 先分帧拖到底（外层获得少量转发，保证内层中心仍在视口内）
    await tester.timedDrag(inner, const Offset(0, -400), const Duration(milliseconds: 300));
    await tester.pump();
    expect(outer.position.pixels, greaterThan(0));

    // 内层向上拖：先耗尽内层滚动距离（250），余量反向转给外层
    await tester.timedDrag(inner, const Offset(0, 400), const Duration(milliseconds: 300));
    await tester.pump();
    final innerPos = innerPosition(tester);
    expect(innerPos.pixels, closeTo(innerPos.minScrollExtent, 1));
    final before = outer.position.pixels;
    expect(before, lessThan(400)); // 反向转发已把外层拉回

    // 内层已在顶部，继续上拖 → 外层继续向上
    await tester.timedDrag(inner, const Offset(0, 100), const Duration(milliseconds: 100));
    await tester.pump();
    expect(outer.position.pixels, lessThan(before));
  });

  testWidgets('内层未到边界时拖动不外传', (tester) async {
    final outer = ScrollController();
    addTearDown(outer.dispose);
    await tester.pumpWidget(
      chainHarness(outer, DiffCodeBlock(diff: patchLines(30))),
    );

    final inner = find.byType(ListView).at(1);
    await tester.timedDrag(inner, const Offset(0, -100), const Duration(milliseconds: 100)); // 内层中间，未到底
    await tester.pump();

    final innerPos = innerPosition(tester);
    expect(innerPos.pixels, greaterThan(0));
    expect(innerPos.pixels, lessThan(innerPos.maxScrollExtent));
    expect(outer.position.pixels, 0); // 外层未被拉动
  });

  testWidgets('深度思考/工具结果文本同样由外层接管', (tester) async {
    final outer = ScrollController();
    addTearDown(outer.dispose);
    final text = List.generate(30, (i) => 'line $i').join('\n');
    await tester.pumpWidget(
      chainHarness(
        outer,
        VirtualParagraphText(
          text: text,
          splitMode: ParagraphSplitMode.newline,
          fontSize: 14,
          lineHeight: 20,
          maxHeight: 320,
          paragraphPaddingBlock: 0,
          paragraphGap: 4,
        ),
      ),
    );

    final inner = find.byType(ListView).at(1);
    // 30 行 × 24 ≈ 720 高，封顶 320 → 滚动范围 ≈ 400；拖 600 到底 + 余量
    await tester.timedDrag(
      inner,
      const Offset(0, -600),
      const Duration(milliseconds: 400),
    );
    await tester.pump();

    final innerPos = innerPosition(tester);
    expect(innerPos.pixels, closeTo(innerPos.maxScrollExtent, 1));
    expect(outer.position.pixels, greaterThan(0));

    // 内层中心可能已被转发推出视口：先滚回外层顶部（不影响验证目标），
    // 保证下一次拖动的起点命中内层
    outer.jumpTo(0);
    await tester.pump();

    final before = outer.position.pixels;
    await tester.timedDrag(
      inner,
      const Offset(0, -100),
      const Duration(milliseconds: 100),
    );
    await tester.pump();
    expect(outer.position.pixels, greaterThan(before));
  });

  testWidgets('内层在底松手后动量传递给外层（惯性滚动）', (tester) async {
    final outer = ScrollController();
    addTearDown(outer.dispose);
    await tester.pumpWidget(
      chainHarness(outer, DiffCodeBlock(diff: patchLines(30))),
    );

    final inner = find.byType(ListView).at(1);
    // 拖到底（外层获得少量转发）
    await tester.timedDrag(
      inner,
      const Offset(0, -400),
      const Duration(milliseconds: 300),
    );
    await tester.pump();
    final innerPos = innerPosition(tester);
    expect(innerPos.pixels, closeTo(innerPos.maxScrollExtent, 1));

    final before = outer.position.pixels;
    expect(before, greaterThan(0));
    // fling 后外层惯性滚动可能把内层滚出视口（ListView 虚拟化卸载），
    // 保存的 innerPos 引用仍可用于后续断言

    // 在边界处快速上滑松手：惯性速度应转给外层，外层继续滚动
    await tester.fling(inner, const Offset(0, -60), 3000);
    await tester.pumpAndSettle();
    expect(outer.position.pixels, greaterThan(before));
    // 内层停在底部（动量已转出，自身不启动模拟）
    expect(innerPos.pixels, innerPos.maxScrollExtent);
  });

  testWidgets('内层在中间松手时动量不外传', (tester) async {
    final outer = ScrollController();
    addTearDown(outer.dispose);
    await tester.pumpWidget(
      chainHarness(outer, DiffCodeBlock(diff: patchLines(30))),
    );

    final inner = find.byType(ListView).at(1);
    // 滚到中间（未到边界）
    await tester.timedDrag(
      inner,
      const Offset(0, -120),
      const Duration(milliseconds: 120),
    );
    await tester.pump();
    final innerPos = innerPosition(tester);
    expect(innerPos.pixels, greaterThan(0));
    expect(innerPos.pixels, lessThan(innerPos.maxScrollExtent));
    expect(outer.position.pixels, 0);

    // 中间 fling：内层自身惯性衰减，动量不转外层
    await tester.fling(inner, const Offset(0, -60), 3000);
    await tester.pumpAndSettle();
    expect(outer.position.pixels, 0);
  });
}
