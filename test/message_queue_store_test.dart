import 'package:flutter_test/flutter_test.dart';

import 'package:agent/store/message_queue_store.dart';
import 'package:agent/store/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = MessageQueueStore.instance;

  tearDown(() {
    // 恢复默认选中态并清理缓存，避免跨测试污染
    SessionStore.instance.selectedId.value = null;
  });

  test('syncFromRust 只把选中会话的队列反映到面板，其余仅缓存', () {
    SessionStore.instance.selectedId.value = 'sessionA';

    // A 的队列到达（A 为选中会话）→ 面板更新
    store.syncFromRust('sessionA', ['msg-a'], [false]);
    expect(store.queue.value.map((m) => m.text), ['msg-a']);

    // B 的队列到达（B 非选中）→ 仅缓存，面板不变（双流并发不互相覆盖）
    store.syncFromRust('sessionB', ['msg-b1', 'msg-b2'], [false, true]);
    expect(store.queue.value.map((m) => m.text), ['msg-a']);

    // 切到 B 会话 → 面板显示 B 的队列（走缓存，不依赖 Rust 重发 QueueState）
    SessionStore.instance.selectedId.value = 'sessionB';
    store.showQueueFor('sessionB');
    expect(store.queue.value.map((m) => m.text), ['msg-b1', 'msg-b2']);
    expect(store.queue.value[1].steer, isTrue);

    // 切回 A（缓存仍在）→ 显示 A 的队列
    SessionStore.instance.selectedId.value = 'sessionA';
    store.showQueueFor('sessionA');
    expect(store.queue.value.map((m) => m.text), ['msg-a']);

    // 无缓存的会话 → 空队列
    store.showQueueFor('sessionC');
    expect(store.queue.value, isEmpty);

    store.forgetSession('sessionA');
    store.forgetSession('sessionB');
  });
}
