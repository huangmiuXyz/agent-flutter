/// 流式对话结束通知中心
///
/// [SessionStore] 在流结束（Done / Error / 启动失败）时调用 [notify]，
/// UI 层通过 [notices] 信号渲染右下角弹窗通知，超时或手动关闭后移除。
library;

import 'dart:async';

import 'package:signals_flutter/signals_flutter.dart';

/// 一条流结束通知
class StreamCompletionNotice {
  final int id;
  final String sessionId;
  final String title;
  final String message;
  final bool isError;

  const StreamCompletionNotice({
    required this.id,
    required this.sessionId,
    required this.title,
    required this.message,
    this.isError = false,
  });
}

/// 流式对话结束通知中心 — 全局单例（信号版）
class NotificationStore {
  static final instance = NotificationStore._();
  NotificationStore._();

  /// 当前在屏的通知列表（新通知追加在尾部，渲染在最下方）
  final notices = signal(<StreamCompletionNotice>[]);

  /// 通知在屏时长，超时自动关闭
  static const Duration displayDuration = Duration(seconds: 6);

  int _nextId = 0;
  final Map<int, Timer> _timers = {};

  /// 弹出通知；同会话连续结束时旧通知仍在屏，可同时叠加显示。
  void notify({
    required String sessionId,
    required String title,
    required String message,
    bool isError = false,
  }) {
    final notice = StreamCompletionNotice(
      id: _nextId++,
      sessionId: sessionId,
      title: title,
      message: message,
      isError: isError,
    );
    notices.value = [...notices.value, notice];
    _timers[notice.id] = Timer(displayDuration, () => dismiss(notice.id));
  }

  /// 关闭指定通知
  void dismiss(int id) {
    _timers.remove(id)?.cancel();
    notices.value = notices.value.where((n) => n.id != id).toList();
  }

  /// 清空全部通知（应用退出等场景）
  void clear() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    notices.value = [];
  }
}
