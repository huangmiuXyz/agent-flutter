import 'dart:async';

import 'package:nanoid/nanoid.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:agent/rust_bridge/api/steer.dart' as api;
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
/// 队列状态全量存储在 Rust `STEER_QUEUE` 中（按 session 分桶）。
/// Dart 只做两件事：
///   1. 用户操作（增/删/切 Steer）→ 直接调 FRB 到 Rust
///   2. 收到 Rust 的 `QueueState` 事件 → 更新对应会话的队列缓存，
///      并把「当前选中会话」的队列反映到 `queue` signal 供 UI 展示
///
/// 各会话的 `QueueState` 事件到达顺序不定：双会话同时流式时若直接
/// 覆盖全局 signal，面板会显示与操作对象（`selectedId`）不一致的队列，
/// 导致误删/误发。因此按 session 缓存，面板只展示选中会话的队列。
class MessageQueueStore {
  static final instance = MessageQueueStore._();
  MessageQueueStore._();

  /// 队列内容（响应式）— 始终等于「当前选中会话」的队列
  final queue = signal(<QueuedMessage>[]);

  /// 每个 session 的队列缓存（`QueueState` 事件写入，选中时展示）
  final Map<String, List<QueuedMessage>> _queuesBySession = {};

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

  /// 用 Rust 队列状态刷新对应会话的缓存（由 QueueState 事件触发）。
  ///
  /// 只把当前选中会话的队列反映到面板，其余会话仅缓存，
  /// 避免双会话并发时队列面板在两个队列之间跳动。
  void syncFromRust(String sessionId, List<String> items, List<bool> flags) {
    final list = [
      for (int i = 0; i < items.length; i++)
        QueuedMessage(
          text: items[i],
          steer: flags.length > i ? flags[i] : false,
        ),
    ];
    _queuesBySession[sessionId] = list;
    if (sessionId == _sessionId) {
      queue.value = list;
    }
  }

  /// 选中会话变化时调用：面板切换为对应会话的队列（无缓存视为空）。
  ///
  /// Rust 不会因切换会话重发 `QueueState`，不主动切换展示的话，
  /// 面板会残留上一个会话的队列。
  void showQueueFor(String sessionId) {
    queue.value = List.of(_queuesBySession[sessionId] ?? const []);
  }

  /// 会话删除时清理缓存，避免残留队列在会话重建后错误展示。
  void forgetSession(String sessionId) {
    _queuesBySession.remove(sessionId);
  }
}
