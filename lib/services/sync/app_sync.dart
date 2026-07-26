/// 应用级跨窗口同步。
///
/// 通过 [SignalsObserver] 全局监听 signal 变化，
/// 当 ConfigStore.data 变动时广播通知其他窗口。
/// 其他窗口收到后 reload ConfigStore，所有 computed 自动更新。
library;

import 'package:signals/signals.dart';

import 'package:agent/services/sync/cross_window_sync.dart';
import 'package:agent/store/config_store.dart';

/// 防循环标志
bool _syncing = false;

/// 缓存 ConfigStore.data 引用，避免在 observer 回调中
/// 访问 ConfigStore.instance 导致 re-entrant 初始化死循环。
Signal<Map<String, dynamic>>? _dataSignal;

/// 初始化跨窗口同步（每个窗口启动时调用一次）。
void initAppSync() {
  // 通用广播层
  CrossWindowSync.init();

  // 先主动初始化 ConfigStore，再设置 observer。
  // 否则 ConfigStore._() 中 _load() 设置 data.value 时，
  // beforeUpdate → onSignalUpdated → ConfigStore.instance
  // 会触发 static final 字段的 re-entrant 初始化 → StackOverflow。
  _dataSignal = ConfigStore.instance.data;

  // 全局监听本地 signal 变化
  SignalsObserver.instance = _SignalObserver();

  // 监听远端通知 → reload ConfigStore
  CrossWindowSync.on('configChanged', _handleRemoteConfigChanged);
}

void _handleRemoteConfigChanged() {
  if (_syncing) return;
  _syncing = true;
  ConfigStore.instance.reload();
  _syncing = false;
}

class _SignalObserver extends SignalsObserver {
  @override
  void onSignalUpdated<T>(Signal<T> instance, T value) {
    if (_syncing) return;

    // 只关注根 ConfigStore.data，computed 会自动跟着变
    if (identical(instance, _dataSignal)) {
      CrossWindowSync.notify('configChanged');
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
