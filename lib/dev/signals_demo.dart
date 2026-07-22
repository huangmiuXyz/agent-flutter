import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

// ──────────────────────────────────────────────
// 1. 基础信号 — signal / computed / effect
// ──────────────────────────────────────────────

final counter = signal(0); // 可变的响应式值
final doubled = computed(() => counter.value * 2); // 派生值

// effect 自动追踪依赖，依赖变化时自动重跑
final disposeEffect = effect(() {
  debugPrint('[effect] counter = ${counter.value}, doubled = ${doubled.value}');
});

// ──────────────────────────────────────────────
// 2. 模拟 SessionManager — 纯 signal 版
// ──────────────────────────────────────────────

class Message {
  final String id;
  final String text;
  const Message(this.id, this.text);
}

/// 纯信号驱动的 SessionManager
/// 不再继承 ChangeNotifier，不依赖任何框架
class SessionManager {
  static final instance = SessionManager._();
  SessionManager._();

  /// 会话列表
  final sessions = signal(<String, List<Message>>{});

  /// 当前会话 ID
  final selectedId = signal<String?>(null);

  /// 结构变更计数器 — 通知消息列表重建
  final structureTick = signal(0);

  /// 流式内容更新 — 通知某条消息刷新文本
  final streamingPartId = signal<String?>(null);

  /// 切换到某个会话（模拟异步加载）
  Future<void> switchTo(String id) async {
    selectedId.value = id;
    await Future.delayed(const Duration(milliseconds: 500));

    final messages = List.generate(
      5,
      (i) => Message('$id-msg-$i', '会话 $id 的第 ${i + 1} 条消息'),
    );
    sessions.value = {...sessions.value, id: messages};
    structureTick.value++; // 触发消息列表重建
  }

  /// 添加一条消息（模拟用户发送）
  void addMessage(String text) {
    final id = selectedId.value;
    if (id == null) return;

    final msgId = '$id-msg-${DateTime.now().millisecondsSinceEpoch}';
    final msg = Message(msgId, text);
    final current = List<Message>.from(sessions.value[id] ?? []);
    sessions.value = {
      ...sessions.value,
      id: [...current, msg],
    };
    structureTick.value++;
  }

  /// 模拟流式打字效果
  Future<void> streamMessage(String fullText) async {
    final id = selectedId.value;
    if (id == null) return;

    final msgId = '$id-msg-stream';
    final buf = StringBuffer();

    for (int i = 0; i < fullText.length; i++) {
      buf.write(fullText[i]);
      final current = List<Message>.from(sessions.value[id] ?? []);
      if (current.isNotEmpty && current.last.id == msgId) {
        current.removeLast();
      }
      sessions.value = {
        ...sessions.value,
        id: [...current, Message(msgId, buf.toString())],
      };
      streamingPartId.value = msgId; // 只通知这条消息
      await Future.delayed(const Duration(milliseconds: 50));
    }
    structureTick.value++; // 流结束，全量重建
  }
}

// ──────────────────────────────────────────────
// 3. UI
// ──────────────────────────────────────────────

class SignalsDemo extends StatefulWidget {
  const SignalsDemo({super.key});
  @override
  State<SignalsDemo> createState() => _SignalsDemoState();
}

class _SignalsDemoState extends State<SignalsDemo> {
  @override
  void initState() {
    super.initState();
    SessionManager.instance.switchTo('demo-1');
  }

  @override
  void dispose() {
    disposeEffect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Signals Demo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),

        // ── 基础 signal 演示 ──
        const _CounterSection(),

        const Divider(),

        // ── Chat 演示 ──
        const Expanded(child: _ChatPanel()),

        const Divider(),

        // ── 操作按钮 ──
        const _ActionBar(),
      ],
    );
  }
}

/// 计数器区块
class _CounterSection extends StatelessWidget {
  const _CounterSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📊 signal + computed + SignalBuilder',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // SignalBuilder 自动追踪内部读到的 signal
                  SignalBuilder(
                    builder: (_) => Text(
                      'counter: ${counter.value}',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SignalBuilder(
                    builder: (_) => Text(
                      'doubled: ${doubled.value}',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => counter.value++,
                child: const Text('+1'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 消息列表 — 只监听 structureTick
class _ChatPanel extends StatelessWidget {
  const _ChatPanel();

  @override
  Widget build(BuildContext context) {
    // SignalBuilder 只追踪 builder 内部读到的 signal
    // 这里读了 structureTick.value 和 selectedId.value
    // streamingPartId  的变更不会触发这里重建
    return SignalBuilder(
      builder: (_) {
        final manager = SessionManager.instance;
        manager.structureTick.value; // 追踪结构变更
        final id = manager.selectedId.value;

        if (id == null) return const Center(child: Text('未选择会话'));

        final messages = manager.sessions.value[id] ?? [];
        if (messages.isEmpty) return const Center(child: Text('暂无消息'));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: messages.length,
          itemBuilder: (_, i) =>
              _MessageItem(key: ValueKey(messages[i].id), message: messages[i]),
        );
      },
    );
  }
}

/// 单条消息 — 独立 SignalBuilder，只在自己有流式更新时重建
class _MessageItem extends StatelessWidget {
  final Message message;
  const _MessageItem({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (_) {
        final streamingId = SessionManager.instance.streamingPartId.value;
        final isStreaming = streamingId == message.id;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: isStreaming ? Colors.blue[50] : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: Text(message.text)),
                if (isStreaming)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 操作按钮
class _ActionBar extends StatelessWidget {
  const _ActionBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SignalBuilder(
            builder: (_) => Text(
              '当前: ${SessionManager.instance.selectedId.value ?? "无"}  ',
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: () {
              SessionManager.instance.addMessage(
                '用户消息 ${DateTime.now().millisecond}',
              );
            },
            child: const Text('发送消息'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: () {
              SessionManager.instance.streamMessage(
                '这是一段流式输出的长文本，每个字逐字出现… ' * 3,
              );
            },
            child: const Text('模拟流式'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: () {
              SessionManager.instance.switchTo('demo-2');
            },
            child: const Text('切换会话'),
          ),
        ],
      ),
    );
  }
}
