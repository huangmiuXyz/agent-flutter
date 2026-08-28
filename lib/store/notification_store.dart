/// 应用内通知中心（信号版）
///
/// 两类通知共用右下角弹层（[StreamCompletionNotifications]）：
/// - 流式对话结束通知：调用 [notify] 并传 [sessionId]（点击卡片切换到会话，
///   同时发送系统级通知）
/// - 通用操作提示（原 SnackBar 职责）：[sessionId] 为空（点击仅关闭，
///   不发系统通知），如「已删除」「保存失败」等
library;

import 'dart:async';

import 'package:signals_flutter/signals_flutter.dart';

import 'package:agent/services/notification/system_notification_service.dart';

/// 一条通知
class StreamCompletionNotice {
  final int id;

  /// 关联会话；为空 = 通用提示（点击不切换会话、不触发系统通知）
  final String? sessionId;
  final String title;
  final String message;
  final bool isError;

  /// 自定义图标名；null = 按 [isError] 取 alertCircle / check。
  final String? icon;

  /// 需要用户注意但非错误（如工具权限待批准）：图标与标题用 warning 色。
  final bool warning;

  const StreamCompletionNotice({
    required this.id,
    this.sessionId,
    required this.title,
    required this.message,
    this.isError = false,
    this.icon,
    this.warning = false,
  });
}

/// 应用内通知中心 — 全局单例（信号版）
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
  ///
  /// [sessionId] 非空（流结束通知）：同时发送系统级通知（应用内弹窗保留，
  /// 两者并存），点击卡片切换到对应会话。
  /// [sessionId] 为空（通用操作提示，替代 SnackBar）：仅应用内右下角弹出。
  void notify({
    String? sessionId,
    String title = '',
    required String message,
    bool isError = false,
    Duration? duration,
    String? icon,
    bool warning = false,
  }) {
    final notice = StreamCompletionNotice(
      id: _nextId++,
      sessionId: sessionId,
      title: title,
      message: message,
      isError: isError,
      icon: icon,
      warning: warning,
    );
    notices.value = [...notices.value, notice];
    _timers[notice.id] = Timer(
      duration ?? displayDuration,
      () => dismiss(notice.id),
    );

    // 系统通知：payload 携带 sessionId，点击后由服务切换到对应会话。
    // 通用提示（无会话归属）不发送系统通知。
    if (sessionId != null) {
      unawaited(
        SystemNotificationService.instance.show(
          id: notice.id,
          title: title,
          body: message,
          sessionId: sessionId,
        ),
      );
    }
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
