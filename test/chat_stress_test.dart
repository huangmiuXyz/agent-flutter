import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent/features/chat/panels/chat_content.dart';
import 'package:agent/rust_bridge/api/types.dart' as api;
import 'package:agent/rust_bridge/events.dart';
import 'package:agent/services/engine/engine_client.dart';
import 'package:agent/services/session/part_types.dart';
import 'package:agent/services/session/session_state.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/app_theme.dart';
import 'package:agent/widgets/loading/app_loading.dart';

/// 大量工具调用 + 大量文字输出下的前端卡顿（jank）集成测试。
///
/// 走真实生产链路：EngineClient 事件注入 → SessionStore 订阅路由 →
/// StreamEventProcessor 应用 → signals 通知 → ChatContent 重建。
/// 初始化先灌入 1000 个已完成工具调用（模拟历史会话加载），
/// 随后在流式输出中持续追加文本 chunk 与新工具调用，逐帧测量：
/// - 每帧真实耗时（Stopwatch 包裹 tester.pump，FakeAsync 下仍为真实时钟）
/// - FrameTiming 的 build/layout 耗时（widget test 下可能为空，仅作辅助）
///
/// 注意：不发送 Done 事件 —— Done 会触发 `api.consumeNonSteer` 的 Rust
/// 调用，在无 Rust 运行时环境中产生未处理异常。
void main() {
  const sessionId = 'stress_session';
  const assistantMsgId = 'ast_main';
  const userMsgId = '${sessionId}_user';

  // ── 测量辅助 ──

  /// 记录每帧耗时（pump 一次 = 一帧）
  final frameTimes = <Duration>[];
  /// 事件应用耗时（flush 微任务，不含帧构建）
  final applyTimes = <Duration>[];
  final frameTimings = <FrameTiming>[];

  /// 收集 FrameTiming（build 耗时，widget test 下可能为空，仅作辅助）
  void collectFrameTimings(List<FrameTiming> timings) {
    frameTimings.addAll(timings);
  }

  /// 注入事件 → flush 事件应用微任务 → pump 一帧，分别记录各段耗时。
  Future<void> injectAndPump(
    WidgetTester tester,
    List<EngineEvent> events,
  ) async {
    for (final e in events) {
      EngineClient.instance.injectEvent(e);
    }
    // 事件应用：广播流在微任务中投递，idle() 只 flush 微任务不渲染帧
    final applySw = Stopwatch()..start();
    await tester.binding.idle();
    applySw.stop();
    applyTimes.add(applySw.elapsed);
    // 帧构建
    final frameSw = Stopwatch()..start();
    await tester.pump();
    frameSw.stop();
    frameTimes.add(frameSw.elapsed);
  }

  /// 帧区间平均耗时（用于相对增长断言）
  Duration avgFrameOf(int start, int end) {
    final slice = frameTimes.sublist(start, end);
    if (slice.isEmpty) return Duration.zero;
    return Duration(
      microseconds:
          slice.fold<int>(0, (a, b) => a + b.inMicroseconds) ~/ slice.length,
    );
  }

  // ── 事件工厂 ──

  /// 文本增量 chunk（totalLen 严格递增以绕过去重：后端保证单调，
  /// 去重逻辑只比较大小，与内容实际长度无关）
  EngineEvent textChunk(int n, String text) {
    final content = '${String.fromCharCode(0x30A0 + (n % 60))}$text';
    return EngineEvent.chunk(
      sessionId: sessionId,
      msgId: assistantMsgId,
      partId: 'part_text',
      content: content,
      totalLen: BigInt.from((n + 1) * 1000),
    );
  }

  /// 一段流式工具调用：3 个参数片段 + 1 个完成事件
  List<EngineEvent> toolCallGroup(int n) {
    final partId = 'part_tool_$n';
    final args = '{"path":"/repo/src/file_$n.dart","content":"line1\\nline2"}';
    return [
      EngineEvent.toolCallFragment(
        sessionId: sessionId,
        msgId: assistantMsgId,
        partId: partId,
        index: 0,
        id: partId,
        name: 'read_file',
        arguments: args.substring(0, 20),
        totalLen: BigInt.from(20),
      ),
      EngineEvent.toolCallFragment(
        sessionId: sessionId,
        msgId: assistantMsgId,
        partId: partId,
        index: 0,
        id: partId,
        name: 'read_file',
        arguments: args.substring(0, 45),
        totalLen: BigInt.from(45),
      ),
      EngineEvent.toolCallFragment(
        sessionId: sessionId,
        msgId: assistantMsgId,
        partId: partId,
        index: 0,
        id: partId,
        name: 'read_file',
        arguments: args,
        totalLen: BigInt.from(args.length),
      ),
      EngineEvent.toolCall(
        sessionId: sessionId,
        msgId: assistantMsgId,
        partId: partId,
        toolName: 'read_file',
        arguments: args,
        result: '{"ok":true,"lines":${n * 7 + 3}}',
      ),
    ];
  }

  /// 已完成工具调用（初始化历史加载用，直接完成态）
  EngineEvent completedToolCall(int n) {
    final partId = 'part_tool_$n';
    final args = '{"path":"/repo/src/file_$n.dart","mode":"write"}';
    return EngineEvent.toolCall(
      sessionId: sessionId,
      msgId: assistantMsgId,
      partId: partId,
      toolName: 'write_file',
      arguments: args,
      result: '{"ok":true,"bytes":$n}',
    );
  }

  /// 建立会话订阅（DB 读取在无 Rust 环境下失败，被 switchTo 内部吞掉）
  Future<void> openSession(WidgetTester tester) async {
    SessionStore.instance.sessions.value = {
      sessionId: SessionState(sessionId),
    };
    await SessionStore.instance.switchTo(sessionId);

    // 手动构造用户消息 + 标记流式（sendMessage 会走 Rust chatStream，不可用）
    final s = SessionStore.instance.stateFor(sessionId)!;
    s.messageOrder.add(userMsgId);
    s.partsByMsg[userMsgId] = [
      api.PartInfo(
        id: '${userMsgId}_part',
        msgId: userMsgId,
        seq: 0,
        partType: PartTypes.text,
        content: '请帮我重构这个项目',
      ),
    ];
    s.messageRoles[userMsgId] = 'user';
    SessionStore.instance.streamingSessionIds.value = {sessionId};
    SessionStore.instance.sessions.value = {
      ...SessionStore.instance.sessions.value,
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: Scaffold(body: ChatContent()),
      ),
    );
  }

  setUp(() {
    frameTimes.clear();
    applyTimes.clear();
    frameTimings.clear();
    SchedulerBinding.instance.addTimingsCallback(collectFrameTimings);
    // 重置全局单例状态（SessionStore 为进程级单例）
    SessionStore.instance.sessions.value = {};
    SessionStore.instance.selectedId.value = null;
    SessionStore.instance.displayedSessionId.value = null;
    SessionStore.instance.streamingSessionIds.value = {};
  });

  tearDown(() {
    SchedulerBinding.instance.removeTimingsCallback(collectFrameTimings);
    // 关闭会话订阅与 EngineClient 的 session controller，
    // 避免残留订阅/监听污染下一个测试（同 sessionId 复用订阅）。
    SessionStore.instance.unsubscribeSession(sessionId);
  });

  testWidgets(
    '初始化 1000 个工具调用 + 流式追加 600 文本 chunk 与 60 组工具调用，'
    '帧耗时与总耗时保持在上限内且无明显渐进恶化',
    (tester) async {
      await openSession(tester);
      await tester.pump();

      // ── 初始化：一次性注入 1000 个已完成工具调用 + 10KB 文本（模拟历史加载） ──
      final initEvents = <EngineEvent>[
        for (int i = 0; i < 1000; i++) completedToolCall(i),
        for (int i = 0; i < 100; i++)
          textChunk(i, '功能模块 $i 说明：\n- 要点一\n- 要点二\n\n'),
      ];
      final initSw = Stopwatch()..start();
      for (final e in initEvents) {
        EngineClient.instance.injectEvent(e);
      }
      await tester.pump(); // 事件应用 + 首帧（卡片渲染；文本增量重放在微任务中）
      await tester.pump(); // 文本内容渲染
      await tester.pump(); // jumpTo 后 item 重建，新 controller 重放完成渲染
      initSw.stop();
      frameTimes.add(initSw.elapsed);

      // 渲染正确性：初始化后视口在底部 — 文本内容可见；工具卡片在视口
      // 上方，被 part 级虚拟化跳过构建（这正是性能提升的来源），滚动后可见
      expect(
        find.textContaining('功能模块'),
        findsWidgets,
        reason: '初始化后应渲染出文本内容',
      );
      await tester.drag(find.byType(ListView), const Offset(0, 100000));
      await tester.pump();
      expect(
        find.textContaining('工具调用'),
        findsWidgets,
        reason: '初始化后应渲染出工具调用卡片',
      );
      await tester.drag(find.byType(ListView), const Offset(0, -100000));
      await tester.pump();

      // ── 流式阶段：600 文本 chunk（30KB）+ 60 组工具调用，逐帧推进 ──
      // 每轮 = 12 个文本 chunk + 2 组工具调用（8 个事件），pump 一帧
      final streamSw = Stopwatch()..start();
      for (int round = 0; round < 50; round++) {
        final events = <EngineEvent>[
          for (int i = 0; i < 12; i++)
            textChunk(
              100 + round * 12 + i,
              '第 $round 轮增量内容 ${'abcde' * 10}\n',
            ),
          ...toolCallGroup(1000 + round * 2),
          ...toolCallGroup(1000 + round * 2 + 1),
        ];
        await injectAndPump(tester, events);
      }
      streamSw.stop();

      // 总耗时 = 初始化（注入+首帧）+ 流式全部轮次（注入+应用+帧）
      final total = initSw.elapsed + streamSw.elapsed;
      // 帧统计：index 0 为初始化帧（一次性历史加载），其余为流式帧
      final initFrame = frameTimes.first;
      final streamFrames = frameTimes.sublist(1);
      final maxStreamFrame = streamFrames.fold<Duration>(
        Duration.zero,
        (a, b) => a > b ? a : b,
      );
      final avgStreamFrame = Duration(
        microseconds: streamFrames.fold<int>(0, (a, b) => a + b.inMicroseconds) ~/
            streamFrames.length,
      );
      final avgApply = Duration(
        microseconds: applyTimes.fold<int>(0, (a, b) => a + b.inMicroseconds) ~/
            applyTimes.length,
      );

      // ── 指标输出（便于人工确认具体数值） ──
      // ignore: avoid_print
      print('=== 前端压力测试指标 ===');
      // ignore: avoid_print
      print('初始化帧（1000 工具调用 + 10KB 文本首帧）: '
          '${initFrame.inMilliseconds}ms');
      // ignore: avoid_print
      print('流式帧数: ${streamFrames.length}');
      // ignore: avoid_print
      print('流式平均帧: ${avgStreamFrame.inMilliseconds}ms');
      // ignore: avoid_print
      print('流式最大帧: ${maxStreamFrame.inMilliseconds}ms');
      // ignore: avoid_print
      print('事件应用平均: ${avgApply.inMicroseconds}us');
      // ignore: avoid_print
      print('初始化阶段耗时: ${initSw.elapsed.inMilliseconds}ms');
      // ignore: avoid_print
      print('流式阶段耗时: ${streamSw.elapsed.inMilliseconds}ms');
      // ignore: avoid_print
      print('总耗时: ${total.inMilliseconds}ms');
      final half = streamFrames.length ~/ 2;
      final firstHalfAvg = avgFrameOf(1, 1 + half);
      final secondHalfAvg = avgFrameOf(1 + half, streamFrames.length + 1);
      // ignore: avoid_print
      print('前半程平均帧: ${firstHalfAvg.inMilliseconds}ms, '
          '后半程平均帧: ${secondHalfAvg.inMilliseconds}ms');
      if (frameTimings.isNotEmpty) {
        final buildTotal = frameTimings.fold<Duration>(
          Duration.zero,
          (a, b) => a + b.buildDuration,
        );
        // ignore: avoid_print
        print(
          'FrameTiming 平均 build: '
          '${(buildTotal ~/ frameTimings.length).inMicroseconds}us',
        );
      }

      // ── 断言 ──
      // 1. 总耗时上限：1000 工具调用 + 40KB 文本全程处理不应超过 60s
      //    （捕捉 O(n²) 级事件处理/重建爆炸）
      expect(total, lessThan(const Duration(seconds: 60)),
          reason: '总处理耗时异常，存在 O(n²) 级性能退化');

      // 2. 初始化帧（一次性历史加载首帧）不应灾难性冻结
      //    （套件并行/慢机负载下首帧可达 5s+，10s 仍能捕捉灾难性卡死）
      expect(initFrame, lessThan(const Duration(seconds: 10)),
          reason: '初始化渲染过慢，历史会话加载会卡死 UI');

      // 3. 流式单帧硬上限：不允许灾难性冻结（如 0.5s 以上无响应）
      expect(maxStreamFrame, lessThan(const Duration(milliseconds: 500)),
          reason: '流式输出中出现灾难性长帧，UI 已明显卡死');

      // 4. 流式平均帧宽松上限（Debug widget test 为 JIT 解释执行，
      //    比 Release 慢 3-5 倍；200ms 能区分「可感知掉帧」与「灾难卡顿」，
      //    优化前实测 283-310ms）
      expect(avgStreamFrame, lessThan(const Duration(milliseconds: 200)),
          reason: '流式平均帧耗时过高，持续卡顿');

      // 5. 相对增长：流式后半程平均帧不应超过前半程 5 倍
      //    （内容量仅增长约 4 倍，若每帧全量重解析导致线性退化会显著超限）
      expect(
        secondHalfAvg.inMicroseconds,
        lessThan(firstHalfAvg.inMicroseconds * 5 + 10000),
        reason: '帧耗时随内容量线性恶化，流式渲染未做增量处理',
      );
    },
  );

  testWidgets('流式行级渲染及时性：完整行每帧跟进渲染，无累积滞后', (tester) async {
    await openSession(tester);
    await tester.pump();

    // 注入工具调用触发 itemCount 变化 → 收敛式 jumpTo 把视口精确带到
    // 列表底部（文本区域可见）
    EngineClient.instance.injectEvent(completedToolCall(900));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // 文本 item 必须在视口内（真实跟随底部的场景）
    final scrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    final pos = tester.state<ScrollableState>(scrollable.first).position;
    expect(pos.extentAfter, lessThan(1),
        reason: '收敛式 jumpTo 应把视口带到精确底部，否则流式文本不可见');

    int maxTextLen() {
      var maxLen = 0;
      for (final e in find.byType(Text).evaluate()) {
        final t = e.widget as Text;
        final d = t.data ?? t.textSpan?.toPlainText() ?? '';
        if (d.length > maxLen) maxLen = d.length;
      }
      for (final e in find.byType(RichText).evaluate()) {
        final len = (e.widget as RichText).text.toPlainText().length;
        if (len > maxLen) maxLen = len;
      }
      return maxLen;
    }

    // 逐行注入：每帧 1 个完整行。事件经广播流异步投递，streamdown 在
    // 下一帧渲染 —— 稳态滞后 1 帧，且内容越长渲染越多（不随时间累积）。
    var maxLag = 0;
    var laggyFrames = 0;
    for (int i = 0; i < 150; i++) {
      EngineClient.instance.injectEvent(textChunk(i, 'x\n'));
      await tester.pump();
      final injected = i + 1;
      final rendered = maxTextLen();
      final lag = injected - rendered;
      if (lag > maxLag) maxLag = lag;
      if (lag > 3) laggyFrames++;
    }
    // ignore: avoid_print
    print('逐行流: 最大滞后 $maxLag 行, 滞后>3帧的帧数 $laggyFrames');
    expect(maxLag, lessThanOrEqualTo(2),
        reason: '流式文本应按行实时渲染，不允许成段滞后出现');
    expect(laggyFrames, 0);
  });

  testWidgets('重负载下 UI 仍可交互：工具卡片可展开、列表可滚动', (tester) async {
    await openSession(tester);
    await tester.pump();

    // 注入 1000 个工具调用 + 20KB 文本作为重负载背景
    final initEvents = <EngineEvent>[
      for (int i = 0; i < 1000; i++) completedToolCall(i),
      for (int i = 0; i < 200; i++)
        textChunk(i, '背景内容 $i: ${'x' * 50}\n'),
    ];
    for (final e in initEvents) {
      EngineClient.instance.injectEvent(e);
    }
    await tester.pump(); // 事件应用 + 首帧
    await tester.pump(); // 流式文本内容渲染
    await tester.pump(); // jumpTo 后 item 重建，重放完成渲染

    // 最后追加一个可见的工具调用（列表末尾，滚到底后可见）
    await injectAndPump(tester, toolCallGroup(9999));

    // loading 指示器应保持在视口内（距最后内容 20px，不被挤出视野）
    final loading = find.byType(AppLoading);
    expect(loading, findsWidgets, reason: '流式中应显示 loading 指示器');
    final loadingRect = tester.getRect(loading.last);
    final viewportRect = tester.getRect(find.byType(ListView));
    // ignore: avoid_print
    print('loading bottom: ${loadingRect.bottom.toStringAsFixed(0)} vs '
        'viewport bottom: ${viewportRect.bottom.toStringAsFixed(0)}, '
        'loading bottom 距视口底: '
        '${(viewportRect.bottom - loadingRect.bottom).toStringAsFixed(0)}px');
    expect(
      loadingRect.bottom,
      lessThanOrEqualTo(viewportRect.bottom + 1),
      reason: 'loading 指示器被挤出视口，视口未跟随最新内容',
    );

    // 滚到底部
    // ignore: avoid_print
    print('drag 前找到卡片数: '
        '${find.textContaining('工具调用').evaluate().length}');
    await tester.drag(find.byType(ListView), const Offset(0, -100000));
    await tester.pump();
    // ignore: avoid_print
    print('drag 后找到卡片数: '
        '${find.textContaining('工具调用').evaluate().length}');

    // 1. 点击工具卡片标题 → 展开（显示参数/结果）
    final title = find.textContaining('工具调用').last;
    expect(title, findsOneWidget);
    await tester.tap(title);
    await tester.pump();
    expect(find.textContaining('"ok"'), findsWidgets,
        reason: '展开后应显示工具执行结果');

    // 2. 再次点击 → 收起
    await tester.tap(title);
    await tester.pump();

    // 3. 列表滚动响应正常：已在底部，向下拖回滚 → pixels 减小
    final position = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    ).position;
    final offsetBefore = position.pixels;
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pump();
    expect(position.pixels, lessThan(offsetBefore),
        reason: '重负载下列表拖动应正常响应');
  });
}
