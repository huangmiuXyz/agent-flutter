/// 通用窗口间广播总线。
///
/// 基于每个窗口独享的 [WindowController] 通道实现，
/// 避免共享 [WindowMethodChannel] 的 2 引擎上限限制。
///
/// 用法：
/// ```dart
/// await CrossWindowSync.init();              // 每个窗口启动时
/// CrossWindowSync.on('eventName', handler); // 注册监听
/// CrossWindowSync.notify('eventName');      // 广播通知
/// ```
library;

import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';

class CrossWindowSync {
  CrossWindowSync._();

  static final _handlers = <String, List<void Function(dynamic)>>{};
  static WindowController? _controller;

  /// 初始化监听（每个窗口启动时调用一次）。
  static Future<void> init() async {
    try {
      _controller = await WindowController.fromCurrentEngine();
      await _controller!.setWindowMethodHandler((call) async {
        final list = _handlers[call.method];
        if (list != null) {
          for (final fn in list) {
            fn(call.arguments);
          }
        }
        return null;
      });
    } catch (_) {
      // 非桌面环境忽略
    }
  }

  /// 注册某类通知的监听。
  static void on(String type, void Function(dynamic args) handler) {
    _handlers.putIfAbsent(type, () => []).add(handler);
  }

  /// 取消注册。
  static void off(String type, void Function(dynamic args) handler) {
    final list = _handlers[type];
    if (list != null) {
      list.remove(handler);
      if (list.isEmpty) _handlers.remove(type);
    }
  }

  /// 广播通知到其他窗口。
  static Future<void> notify(String type, [dynamic args]) async {
    try {
      final all = await WindowController.getAll();
      final selfId = _controller?.windowId;
      for (final w in all) {
        if (w.windowId != selfId) {
          unawaited(w.invokeMethod(type, args).catchError((_) {}));
        }
      }
    } catch (_) {
      // 非桌面环境忽略
    }
  }
}
