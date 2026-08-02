/// 文件持久化 store 基类 —「signal ↔ 文件」双向同步
///
/// 职责：
/// 1. 构造时从磁盘加载一次
/// 2. signal 一变，自动写回文件
/// 3. 监听外部文件修改，自动重载（用于跨窗口同步 / 手动编辑）
///
/// 子类只需实现 [loadFromDisk] / [writeToDisk] 两个方法。
/// JSON 结构配置见 [JsonFileSignalStore]。
///
/// ⚠️ [loadFromDisk] 会在构造函数中被调用，[writeToDisk] 会被
/// `effect` 首次执行时调用 —— 两者都发生在子类字段初始化完成之前，
/// 因此实现中**不得访问子类非 late 实例字段**，信号字段请声明为
/// `late final`（首次访问时才会初始化）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:signals/signals.dart';

import 'package:agent/services/sync/file_watcher.dart';

/// 「信号 → 文件」持久化基类（文本 / JSON 通用）。
abstract class FileSignalStore {
  FileSignalStore(this.path) {
    loadFromDisk();
    // 自动持久化：信号一变，立即写文件
    _writeEffect = effect(() => _writeFile());
    // 监听外部文件修改（如手动编辑、其他窗口写入）
    _startWatch();
  }

  /// 持久化文件路径（子类通过 `super(path:)` 传入）。
  final String path;

  /// 从磁盘加载数据到信号（首次加载 + 外部修改重载共用）。
  ///
  /// ⚠️ 构造函数中会调用，不得访问子类非 late 实例字段。
  void loadFromDisk();

  /// 把当前信号内容写回磁盘。
  ///
  /// 返回是否真正写入了文件（内容未变化、现有文件不可覆盖等情况返回
  /// false）。只有真正写入时才刷新「自身写入时间戳」，用于过滤文件
  /// 监听的自触发回调。
  bool writeToDisk();

  /// 从磁盘重新加载（用于窗口间同步）。
  void reload() => loadFromDisk();

  int _lastWriteMs = 0;

  /// 自动持久化 effect，dispose 时释放
  EffectCleanup? _writeEffect;

  /// 文件监听句柄，dispose 时释放
  WatcherDisposable? _watcher;

  /// 释放文件监听与自动持久化订阅。
  ///
  /// 进程级单例 store 在应用退出时调用；调用后不再自动写盘/监听外部修改。
  void dispose() {
    _writeEffect?.call();
    _writeEffect = null;
    _watcher?.dispose();
    _watcher = null;
    _watching = false;
  }

  void _writeFile() {
    if (writeToDisk()) {
      _lastWriteMs = DateTime.now().millisecondsSinceEpoch;
    }
  }

  bool _watching = false;

  void _startWatch() {
    if (_watching) return;
    _watching = true;
    _watcher = watchFileChanges(
      path,
      reload,
      ignoreOwnWrites: () {
        final now = DateTime.now().millisecondsSinceEpoch;
        return (now - _lastWriteMs) < 500;
      },
    );
  }
}

/// JSON 文件持久化 store 基类
///
/// 在 [FileSignalStore] 基础上，把 [data] 信号作为 JSON 文件的
/// 全量内容（直接当 Map 读写）：
/// - [mutate] 便捷更新，改完自动写文件 + 通知 UI
/// - 加载时与 [defaults] 合并，缺失字段自动补齐
/// - 子类可覆写 [mergeDefaults] 做深度合并
abstract class JsonFileSignalStore extends FileSignalStore {
  JsonFileSignalStore(super.path);

  /// 配置全量内容（信号，直接当 Map 读写）。
  ///
  /// `late final`：构造函数中 [loadFromDisk] 首次访问时才初始化。
  late final data = signal(<String, dynamic>{});

  /// 默认配置（文件不存在或缺少字段时使用）。
  ///
  /// ⚠️ 构造函数中会调用，不得访问实例字段。
  Map<String, dynamic> defaults() => {};

  /// 修改数据，改完自动写文件 + 通知 UI。
  void mutate(void Function(Map<String, dynamic> map) fn) {
    final copy = Map<String, dynamic>.from(data.value);
    fn(copy);
    data.value = copy;
  }

  /// 将 [raw] 与 [defaults] 合并。默认浅合并；子类可覆写做深度合并。
  Map<String, dynamic> mergeDefaults(Map<String, dynamic> raw) {
    final merged = Map<String, dynamic>.from(defaults());
    merged.addAll(raw);
    return merged;
  }

  @override
  void loadFromDisk() {
    final file = File(path);
    if (!file.existsSync()) {
      data.value = defaults();
      return;
    }
    try {
      final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final merged = mergeDefaults(raw);
      // 深度比较：内容没变就不更新 data，避免触发 effect(_writeFile)
      // 进而导致 写文件 → FileWatcher → _load → 写文件 的死循环
      if (data.value == merged) return;
      data.value = merged;
    } catch (_) {
      // JSON 解析失败：首次加载用默认值，后续保持现有 data 不变
      if (data.value.isEmpty) {
        data.value = defaults();
      }
    }
  }

  @override
  bool writeToDisk() {
    final file = File(path);
    final content =
        '${const JsonEncoder.withIndent('  ').convert(data.value)}\n';
    if (file.existsSync()) {
      try {
        final existing = file.readAsStringSync();
        if (existing == content) return false;
        // 文件内容不同，但若当前文件 JSON 不合法就不覆盖，
        // 防止用户编辑器里正在编辑/文件损坏时被重置
        jsonDecode(existing);
      } catch (_) {
        return false;
      }
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    return true;
  }
}
