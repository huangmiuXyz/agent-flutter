import 'dart:async';

import 'package:nanoid/nanoid.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/store/session_store.dart';

/// 队列中的一条消息（仅用于 UI 展示，数据来自 Rust）
class QueuedMessage {
  /// 本地 transient ID，仅用于 Flutter widget key
  final String id;
  final String text;
  final bool steer;

  QueuedMessage({String? id, required this.text, required this.steer})
    : id = id ?? nanoid(12);
}

/// 消息队列管理器 — 薄 UI 层
///
/// 队列状态全量存储在 Rust `STEER_QUEUE` 中。
/// Dart 只做两件事：
///   1. 用户操作（增/删/切 Steer）→ 直接调 FRB 到 Rust
///   2. 收到 Rust 的 `QueueState` 事件 → 更新 `queue` signal 供 UI 展示
///
/// 不再独立维护 Dart 侧队列副本。
class MessageQueueStore {
  static final instance = MessageQueueStore._();
  MessageQueueStore._();

  /// 队列内容（响应式）— 仅由 `syncFromRust` 写入
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

  /// 当前选中会话 ID
  String? get _sessionId => SessionStore.instance.selectedId.value;

  // ── 操作（均直接调用 FRB，不维护本地队列） ──

  /// 将消息加入队列尾部
  void enqueue(String text, {bool steer = false}) {
    if (text.trim().isEmpty) return;
    final sid = _sessionId;
    if (sid == null) return;
    expand();

    if (steer) {
      api.enqueueSteerWithFlag(sessionId: sid, text: text.trim());
    } else {
      api.enqueueSteer(sessionId: sid, text: text.trim());
    }
  }

  /// 移除指定索引的消息
  void remove(int index) {
    final sid = _sessionId;
    if (sid == null) return;
    api.removeSteer(sessionId: sid, index: BigInt.from(index));
  }

  /// 编辑指定索引的消息文本（Rust 无原地编辑 API，先删后加，项会移到底部）
  void edit(int index, String newText) {
    if (newText.trim().isEmpty) return;
    final sid = _sessionId;
    if (sid == null) return;
    if (index < 0 || index >= queue.value.length) return;
    final steer = queue.value[index].steer;
    unawaited(_doEdit(sid, index, newText.trim(), steer));
  }

  Future<void> _doEdit(
    String sid,
    int index,
    String newText,
    bool steer,
  ) async {
    try {
      await api.removeSteer(sessionId: sid, index: BigInt.from(index));
      if (steer) {
        await api.enqueueSteerWithFlag(sessionId: sid, text: newText);
      } else {
        await api.enqueueSteer(sessionId: sid, text: newText);
      }
    } catch (_) {
      // 编辑失败不影响核心功能
    }
  }

  /// 切换指定索引消息的 steer 标记
  void toggleSteer(int index) {
    final sid = _sessionId;
    if (sid == null) return;
    api.toggleSteer(sessionId: sid, index: BigInt.from(index));
  }

  /// 清空队列
  void clear() {
    final sid = _sessionId;
    if (sid == null) return;
    api.clearSteer(sessionId: sid);
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

  // ── 从 Rust 同步 ──

  /// 用 Rust 队列状态刷新 UI（由 QueueState 事件触发）
  void syncFromRust(List<String> items, List<bool> flags) {
    queue.value = [
      for (int i = 0; i < items.length; i++)
        QueuedMessage(
          text: items[i],
          steer: flags.length > i ? flags[i] : false,
        ),
    ];
  }
}
