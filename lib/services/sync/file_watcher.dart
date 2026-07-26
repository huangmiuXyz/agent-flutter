/// 文件变更监听工具函数。
///
/// 使用 [package:watcher] 监听文件变化，外部修改时触发回调。
/// 返回 [WatcherDisposable] 可取消监听。
library;

import 'package:watcher/watcher.dart';

/// 监听文件外部变更，变化时调用 [onChanged]。
///
/// [ignoreOwnWrites] 不为 null 时，返回 true 表示是自身写入，跳过回调。
WatcherDisposable watchFileChanges(
  String path,
  void Function() onChanged, {
  bool Function()? ignoreOwnWrites,
}) {
  final watcher = FileWatcher(path);
  final sub = watcher.events.listen((event) {
    if (ignoreOwnWrites != null && ignoreOwnWrites()) return;
    onChanged();
  });
  return WatcherDisposable(() {
    sub.cancel();
  });
}

/// 可取消的资源。
class WatcherDisposable {
  final void Function() _dispose;
  WatcherDisposable(this._dispose);
  void dispose() => _dispose();
}
