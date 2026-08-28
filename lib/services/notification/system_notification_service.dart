/// 系统级流结束通知 — 通过 [flutter_local_notifications] 发送到系统通知中心。
///
/// 与应用内右下角弹窗（[NotificationStore]）并存：
/// - macOS：UNUserNotificationCenter（插件注册自身为 delegate，无需改动 AppDelegate）
/// - Windows：Toast Notifications（FFI 实现，随 Flutter 构建自动打包）
/// - Android：通知渠道 + POST_NOTIFICATIONS 运行时权限（见 [SystemNotificationService.init]）
/// 点击系统通知 → payload 携带 sessionId → 切换到对应会话。
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:agent/store/session_store.dart';

/// 系统级流结束通知服务 — 全局单例。
class SystemNotificationService {
  static final instance = SystemNotificationService._();
  SystemNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Android 8+ 的通知渠道：无渠道则通知一律不显示。
  static const _androidChannelId = 'agent_session';
  static const _androidChannelName = '会话';
  static const _androidChannelDesc = 'AI 回复完成与工具授权请求';

  /// 初始化系统通知通道；macOS 首次调用会请求系统通知授权。
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          macOS: const DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
          windows: const WindowsInitializationSettings(
            appName: 'Agent',
            appUserModelId: 'com.example.agent',
            guid: '68A16985-B951-4894-82B2-A4D8CBCF449E',
          ),
        ),
        onDidReceiveNotificationResponse: _onTap,
      );
      if (Platform.isAndroid) await _initAndroid();
    } catch (_) {
      // 系统通知不可用（如无权限）不阻断应用主流程
    }
  }

  /// Android 专属初始化：POST_NOTIFICATIONS 是 Android 13+ 的运行时权限
  /// （低版本调用为 no-op），渠道必须显式创建，重复创建幂等。
  Future<void> _initAndroid() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    await android.requestNotificationsPermission();
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: _androidChannelDesc,
        importance: Importance.high,
      ),
    );
  }

  /// 弹出系统通知；payload 携带 [sessionId]，点击后跳转到对应会话。
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String sessionId,
  }) async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannelId,
            _androidChannelName,
            channelDescription: _androidChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: sessionId,
      );
    } catch (_) {
      // 通知失败不影响主流程
    }
  }

  /// 点击系统通知 → 切换到对应会话（与应用内弹窗点击行为一致）。
  void _onTap(NotificationResponse response) {
    final sessionId = response.payload;
    if (sessionId == null || sessionId.isEmpty) return;
    final store = SessionStore.instance;
    if (store.selectedId.value != sessionId) {
      store.selectedId.value = sessionId;
    }
    unawaited(store.switchTo(sessionId));
  }
}
