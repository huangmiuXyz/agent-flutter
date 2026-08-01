/// 应用级跨窗口同步。
///
/// 通过 [SignalsObserver] 全局监听 signal 变化，
/// 当 ConfigStore.data 变动时广播通知其他窗口。
/// 其他窗口收到后 reload ConfigStore，所有 computed 自动更新。
library;

import 'dart:async';

import 'package:signals/signals.dart';

import 'package:agent/services/sync/cross_window_sync.dart';
import 'package:agent/store/code_forge_store.dart';
import 'package:agent/store/config_store.dart';
import 'package:agent/store/setting_store.dart';
import 'package:agent/store/theme_store.dart';

/// 防循环标志
bool _syncing = false;

/// 缓存 ConfigStore.data 引用，避免在 observer 回调中
/// 访问 ConfigStore.instance 导致 re-entrant 初始化死循环。
Signal<Map<String, dynamic>>? _dataSignal;

/// 同上，CodeForgeStore.filePath。
Signal<String>? _filePathSignal;

/// 初始化跨窗口同步（每个窗口启动时调用一次）。
Future<void> initAppSync() async {
  // 通用广播层
  await CrossWindowSync.init();

  // 先主动初始化 ConfigStore，再设置 observer。
  // 否则 ConfigStore._() 中 _load() 设置 data.value 时，
  // beforeUpdate → onSignalUpdated → ConfigStore.instance
  // 会触发 static final 字段的 re-entrant 初始化 → StackOverflow。
  _dataSignal = ConfigStore.instance.data;

  // 同上，先主动初始化再注册 observer，避免 re-entrant。
  _filePathSignal = CodeForgeStore.instance.filePath;

  // 主动初始化 SettingStore，并同步到 ThemeStore
  final settingStore = SettingStore.instance;
  ThemeStore.instance.fontFamily.value = settingStore.fontFamily;

  // 全局监听本地 signal 变化
  SignalsObserver.instance = _SignalObserver();

  // 监听远端通知 → reload ConfigStore
  CrossWindowSync.on('configChanged', _handleRemoteConfigChanged);

  // 监听远端通知 → reload CodeForgeStore
  CrossWindowSync.on('fileOpened', _handleRemoteFileOpened);

  // 监听远端通知 → sync font family (direct, no file reload needed)
  CrossWindowSync.on('fontFamilyChanged', _handleRemoteFontFamilyChanged);

  // 监听远端通知 → reload SettingStore 并同步到 ThemeStore
  CrossWindowSync.on('settingChanged', _handleRemoteSettingChanged);
}

/// 在防循环锁内执行 [fn]，避免「本地广播 → 远端收到后 reload → 再广播」死循环。
///
/// 若 [fn] 抛异常也会复位锁，避免永久卡死。
void _withSyncingGuard(void Function() fn) {
  if (_syncing) return;
  _syncing = true;
  try {
    fn();
  } finally {
    _syncing = false;
  }
}

void _handleRemoteConfigChanged(dynamic args) {
  _withSyncingGuard(() => ConfigStore.instance.reload());
}

void _handleRemoteFileOpened(dynamic args) {
  _withSyncingGuard(() => CodeForgeStore.instance.reload());
}

void _handleRemoteFontFamilyChanged(dynamic args) {
  _withSyncingGuard(() {
    if (args is String) {
      ThemeStore.instance.fontFamily.value = args;
    }
  });
}

void _handleRemoteSettingChanged(dynamic args) {
  _withSyncingGuard(() {
    SettingStore.instance.reload();
    ThemeStore.instance.fontFamily.value = SettingStore.instance.fontFamily;
  });
}

class _SignalObserver extends SignalsObserver {
  @override
  void onSignalUpdated<T>(Signal<T> instance, T value) {
    if (_syncing) return;

    // 只关注根 ConfigStore.data，computed 会自动跟着变
    if (identical(instance, _dataSignal)) {
      unawaited(CrossWindowSync.notify('configChanged'));
    }
    if (identical(instance, _filePathSignal)) {
      unawaited(CrossWindowSync.notify('fileOpened'));
    }
    // Broadcast font family changes to other windows
    if (identical(instance, ThemeStore.instance.fontFamily)) {
      unawaited(CrossWindowSync.notify('fontFamilyChanged', value));
    }

    // SettingStore.data 变化 → 持久化 + 广播到其他窗口
    if (identical(instance, SettingStore.instance.data)) {
      unawaited(CrossWindowSync.notify('settingChanged'));
    }
  }

  // 其他方法不需要处理，但必须实现
  @override
  void onSignalCreated<T>(Signal<T> instance, T value) {}

  @override
  void onComputedCreated<T>(Computed<T> instance) {}

  @override
  void onComputedUpdated<T>(Computed<T> instance, T value) {}

  @override
  void onEffectCreated(Effect instance) {}

  @override
  void onEffectCalled(Effect instance) {}

  @override
  void onEffectRemoved(Effect instance) {}
}
