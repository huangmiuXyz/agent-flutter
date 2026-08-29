/// SessionStore 流式状态标记测试 — 后端自发流（子智能体子会话）的 loading 语义。
///
/// 子会话由 Rust 侧 spawn_sub_agent 创建并运行，前端从未对其调用
/// sendMessage/retryMessage，streamingSessionIds 只能靠实时事件补标记。
/// 测试经 EngineClient.injectEvent 走与生产一致的事件路由。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:agent/rust_bridge/events.dart';
import 'package:agent/services/engine/engine_client.dart';
import 'package:agent/store/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = SessionStore.instance;

  /// 建立会话订阅（switchTo 中不可用的 Rust DB 读取均静默降级为空）
  Future<void> subscribe(String sessionId) async {
    await store.switchTo(sessionId);
  }

  /// 注入事件并等待 broadcast 流分发到 SessionStore 监听器
  Future<void> inject(EngineEvent event) async {
    EngineClient.instance.injectEvent(event);
    await pumpEventQueue();
  }

  tearDown(() async {
    await pumpEventQueue();
  });

  test('后端自发流：首个内容事件补标记流式，Done 清除（loading 出现并消失）', () async {
    const sid = 'ses_sub_t1';
    await subscribe(sid);
    expect(store.streamingSessionIds.value.contains(sid), isFalse);

    await inject(
      EngineEvent.chunk(
        sessionId: sid,
        msgId: 'm1',
        partId: 'p1',
        content: '子任务进行中',
        totalLen: BigInt.from(15),
      ),
    );
    expect(store.streamingSessionIds.value.contains(sid), isTrue);

    await inject(EngineEvent.done(sessionId: sid));
    expect(store.streamingSessionIds.value.contains(sid), isFalse);
  });

  test('ToolCallFragment / ToolOutputDelta 同样触发补标记', () async {
    const sid = 'ses_sub_t2';
    await subscribe(sid);

    await inject(
      EngineEvent.toolCallFragment(
        sessionId: sid,
        msgId: 'm1',
        partId: 'tcf_m1_c1',
        index: 0,
        name: 'shell_command',
        arguments: '{"command": "ls"}',
        totalLen: BigInt.from(18),
      ),
    );
    expect(store.streamingSessionIds.value.contains(sid), isTrue);

    await inject(EngineEvent.done(sessionId: sid));
    expect(store.streamingSessionIds.value.contains(sid), isFalse);

    // 流结束后的第二个自发流（下一轮）再由内容事件重新标记
    await inject(
      EngineEvent.toolOutputDelta(
        sessionId: sid,
        msgId: 'm2',
        partId: 'tcf_m2_c1',
        stream: 'stdout',
        chunk: 'out',
        totalLen: BigInt.from(3),
      ),
    );
    expect(store.streamingSessionIds.value.contains(sid), isTrue);
  });

  test('SteerInjected / QueueState 非流内容事件不标记（不破坏自动继续判断）', () async {
    const sid = 'ses_sub_t3';
    await subscribe(sid);

    await inject(
      EngineEvent.steerInjected(
        sessionId: sid,
        text: '[子智能体「x」插入的结果]',
        source: 'sub_agent',
      ),
    );
    await inject(
      EngineEvent.queueState(sessionId: sid, items: ['q'], flags: [false]),
    );
    expect(store.streamingSessionIds.value.contains(sid), isFalse);
  });

  test('显式取消后的旧流残留内容事件不重新标记，Error 也不复活流式', () async {
    const sid = 'ses_sub_t4';
    await subscribe(sid);

    // 标记流式后取消（Rust 调用在测试环境静默失败，不影响本地状态清理）
    await inject(
      EngineEvent.chunk(
        sessionId: sid,
        msgId: 'm1',
        partId: 'p1',
        content: 'a',
        totalLen: BigInt.from(1),
      ),
    );
    expect(store.streamingSessionIds.value.contains(sid), isTrue);
    await store.cancelStreaming(sid);
    expect(store.streamingSessionIds.value.contains(sid), isFalse);

    // 旧流在途的残留事件：内容不重新标记，Done 被忽略
    await inject(
      EngineEvent.chunk(
        sessionId: sid,
        msgId: 'm1',
        partId: 'p1',
        content: 'b',
        totalLen: BigInt.from(2),
      ),
    );
    expect(store.streamingSessionIds.value.contains(sid), isFalse);

    await inject(EngineEvent.error(sessionId: sid, message: 'cancelled'));
    expect(store.streamingSessionIds.value.contains(sid), isFalse);
  });
}
