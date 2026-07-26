import 'dart:convert';
import 'dart:io';

import 'package:signals/signals.dart';

import 'package:agent/services/sync/file_watcher.dart';
import 'package:agent/utils/platform_dirs.dart';
import 'package:agent/features/settings/models/mcp_server_info.dart';

class ConfigStore {
  static final instance = ConfigStore._();
  ConfigStore._() {
    configPath = _resolveConfigPath();
    dbPath = _resolveDbPath();
    _load();

    // 自动持久化：data 信号一变，立即写文件
    effect(() => _writeFile());

    // 监听外部文件修改（手动编辑 config.json）
    _startWatch();
  }

  // ── 路径（一次性解析，不含信号）──

  late final String configPath;
  late final String dbPath;

  // ── config.json 全量内容（信号，直接当 Map 读写）──

  final data = signal(<String, dynamic>{});

  // ── 便捷更新 ──

  /// 从磁盘重新加载配置（用于窗口间同步）。
  void reload() {
    _load();
  }

  /// 修改数据，改完自动写文件 + 通知 UI
  void mutate(void Function(Map<String, dynamic> map) fn) {
    final copy = Map<String, dynamic>.from(data.value);
    fn(copy);
    data.value = copy;
  }

  // ── 衍生信号（从 data 自动计算）──

  /// 当前默认模型名
  late final currentProvider = computed<String>(() {
    final dm = data.value['default_model'];
    if (dm is Map) return dm['provider'] as String? ?? '';
    return '';
  });

  /// 当前默认模型 ID
  late final currentModel = computed<String>(() {
    final dm = data.value['default_model'];
    if (dm is Map) return dm['model'] as String? ?? '';
    return '';
  });

  // ── 类型化更新（避免各页面重复 parse / 写回）──

  /// 更新 MCP 服务器列表，[fn] 拿到当前列表，修改后自动写回。
  void updateMcpServers(void Function(List<McpServerInfo>) fn) {
    mutate((data) {
      final servers = loadMcpServers(data);
      fn(servers);
      saveMcpServers(data, servers);
    });
  }

  // ── 内部 ──

  void _load() {
    final file = File(configPath);
    if (!file.existsSync()) return;
    try {
      data.value = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      data.value = {};
    }
  }

  int _lastWriteMs = 0;

  void _writeFile() {
    final file = File(configPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(data.value)}\n',
    );
    _lastWriteMs = DateTime.now().millisecondsSinceEpoch;
  }

  bool _watching = false;

  void _startWatch() {
    if (_watching) return;
    _watching = true;
    watchFileChanges(
      configPath,
      () {
        reload();
      },
      ignoreOwnWrites: () {
        final now = DateTime.now().millisecondsSinceEpoch;
        return (now - _lastWriteMs) < 500;
      },
    );
  }

  // ── 路径解析（原有逻辑）──

  bool _inProjectDir() {
    return File('./config.json').existsSync() ||
        File('./pubspec.yaml').existsSync() ||
        Directory('./data').existsSync();
  }

  String _resolveConfigPath() {
    const compileEnv = String.fromEnvironment('CONFIG_PATH');
    if (compileEnv.isNotEmpty) return compileEnv;

    final runtimeEnv = Platform.environment['AGENT_CONFIG_PATH'];
    if (runtimeEnv != null && runtimeEnv.isNotEmpty) return runtimeEnv;

    if (_inProjectDir()) return '../agent-flutter-cli/config.json';

    return appDataDir(['agent', 'config.json']);
  }

  String _resolveDbPath() {
    const compileEnv = String.fromEnvironment('DB_PATH');
    if (compileEnv.isNotEmpty) return compileEnv;

    final runtimeEnv = Platform.environment['AGENT_DB_PATH'];
    if (runtimeEnv != null && runtimeEnv.isNotEmpty) return runtimeEnv;

    if (_inProjectDir()) return '../agent-flutter-cli/data/data';

    return appDataDir(['agent', 'data', 'data']);
  }
}
