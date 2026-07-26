/// 通用窗口间广播总线。
///
/// 基于 [WindowMethodChannel] 实现，纯广播不耦合任何业务。
///
/// 用法：
/// ```dart
/// CrossWindowSync.init();                   // 每个窗口启动时
/// CrossWindowSync.on('eventName', handler); // 注册监听
/// CrossWindowSync.notify('eventName');      // 广播通知
/// ```
library;

import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';

class CrossWindowSync {
  CrossWindowSync._();

  static final _handlers = <String, List<void Function()>>{};

  /// 初始化监听（每个窗口启动时调用一次）。
  static void init() {
    try {
      const channel = WindowMethodChannel('cross_window_sync');
      channel.setMethodCallHandler((call) async {
        final list = _handlers[call.method];
        if (list != null) {
          for (final fn in list) {
            fn();
          }
        }
        return null;
      });
    } catch (_) {
      // 非桌面环境忽略
    }
  }

  /// 注册某类通知的监听。
  static void on(String type, void Function() handler) {
    _handlers.putIfAbsent(type, () => []).add(handler);
  }

  /// 取消注册。
  static void off(String type, void Function() handler) {
    final list = _handlers[type];
    if (list != null) {
      list.remove(handler);
      if (list.isEmpty) _handlers.remove(type);
    }
  }

  /// 广播通知到其他窗口。
  static void notify(String type) {
    try {
      const channel = WindowMethodChannel('cross_window_sync');
      unawaited(channel.invokeMethod(type).catchError((_) {}));
    } catch (_) {
      // 非桌面环境忽略
    }
  }
}
