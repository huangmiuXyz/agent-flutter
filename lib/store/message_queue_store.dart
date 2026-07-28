import 'package:nanoid/nanoid.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 队列中的一条消息
class QueuedMessage {
  final String id;
  final String text;
  final bool steer;
  final DateTime createdAt;

  QueuedMessage({
    String? id,
    required this.text,
    this.steer = false,
    DateTime? createdAt,
  }) : id = id ?? nanoid(12),
       createdAt = createdAt ?? DateTime.now();

  QueuedMessage copyWith({String? text, bool? steer}) {
    return QueuedMessage(
      id: id,
      text: text ?? this.text,
      steer: steer ?? this.steer,
      createdAt: createdAt,
    );
  }
}

/// 消息队列管理器
///
/// - `steer=false`（默认）：等当前回复 Done 后自动通过 sendMessage 发出
/// - `steer=true`：在 Rust checkpoint 提前注入到对话上下文中
/// - 点击队列项上的 "Steer" 切换标记
class MessageQueueStore {
  static final instance = MessageQueueStore._();
  MessageQueueStore._();

  /// 队列内容（响应式）
  final queue = signal(<QueuedMessage>[]);

  /// 面板展开/折叠状态
  final expanded = signal(true);

  // ── 查询 ──

  int get count => queue.value.length;
  bool get isEmpty => queue.value.isEmpty;

  /// 是否有 steer=true 的项
  bool get hasSteer => queue.value.any((m) => m.steer);

  /// 是否有 steer=false 的项
  bool get hasNonSteer => queue.value.any((m) => !m.steer);

  // ── 操作 ──

  /// 将消息加入队列尾部（默认 steer=false，普通排队）
  void enqueue(String text, {bool steer = false}) {
    if (text.trim().isEmpty) return;
    queue.value = [
      ...queue.value,
      QueuedMessage(text: text.trim(), steer: steer),
    ];
    expand();
  }

  /// 移除指定 ID 的消息
  void remove(String id) {
    queue.value = queue.value.where((m) => m.id != id).toList();
  }

  /// 编辑指定 ID 的消息文本
  void edit(String id, String newText) {
    if (newText.trim().isEmpty) return;
    queue.value = queue.value.map((m) {
      return m.id == id ? m.copyWith(text: newText.trim()) : m;
    }).toList();
  }

  /// 切换指定 ID 消息的 steer 标记
  void toggleSteer(String id) {
    queue.value = queue.value.map((m) {
      return m.id == id ? m.copyWith(steer: !m.steer) : m;
    }).toList();
  }

  /// 清空队列
  void clear() {
    queue.value = [];
  }

  // ── 消费（供外部调用） ──

  /// 取出第一条 steer=true 的消息并移除，返回其文本。
  /// 队列中无 steer 消息返回 null。
  String? consumeSteer() {
    final idx = queue.value.indexWhere((m) => m.steer);
    if (idx < 0) return null;
    final item = queue.value[idx];
    queue.value = [
      ...queue.value.sublist(0, idx),
      ...queue.value.sublist(idx + 1),
    ];
    return item.text;
  }

  /// 取出第一条 steer=false 的消息并移除，返回其文本。
  /// 队列中无非 steer 消息返回 null。
  String? consumeNonSteer() {
    final idx = queue.value.indexWhere((m) => !m.steer);
    if (idx < 0) return null;
    final item = queue.value[idx];
    queue.value = [
      ...queue.value.sublist(0, idx),
      ...queue.value.sublist(idx + 1),
    ];
    return item.text;
  }

  // ── 面板状态 ──

  void toggleExpanded() {
    expanded.value = !expanded.value;
  }

  void expand() {
    expanded.value = true;
  }

  void collapse() {
    expanded.value = false;
  }
}
