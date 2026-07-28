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

  /// 默认配置（文件不存在或缺少字段时使用）。
  static Map<String, dynamic> _defaultConfig() => {
    'provider': <String>[],
    'default_model': {'provider': '', 'model': ''},
    'mcp_servers': <Map<String, dynamic>>[],
    'skills': <String, dynamic>{},
  };

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

  /// 更新技能启禁状态，[fn] 拿到当前 skill_id → enabled 映射，修改后自动写回。
  /// 和 [updateMcpServers] 模式完全一致。
  void updateSkills(void Function(Map<String, bool>) fn) {
    mutate((data) {
      final states = loadSkillStates(data);
      fn(states);
      _saveSkillStates(data, states);
    });
  }

  /// 从 data 中读取技能启禁状态，返回 skill_id → enabled。
  Map<String, bool> loadSkillStates(Map<String, dynamic> data) {
    final map = data['skills'] as Map<String, dynamic>?;
    if (map == null) return {};
    return map.map((k, v) {
      final entry = v as Map<String, dynamic>?;
      return MapEntry(k, entry?['enabled'] == true);
    });
  }

  /// 将技能启禁状态写回 data。
  void _saveSkillStates(Map<String, dynamic> data, Map<String, bool> states) {
    data['skills'] = {
      for (final e in states.entries)
        e.key: {'enabled': e.value},
    };
  }

  // ── 内部 ──

  void _load() {
    final file = File(configPath);
    if (!file.existsSync()) {
      data.value = _defaultConfig();
      return;
    }
    try {
      final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      // 与默认值合并，确保必要字段都存在
      final merged = Map<String, dynamic>.from(_defaultConfig());
      merged.addAll(raw);
      // default_model 也要合并子键
      if (raw['default_model'] is Map) {
        final dm = Map<String, dynamic>.from(
          _defaultConfig()['default_model'] as Map,
        );
        dm.addAll(Map<String, dynamic>.from(raw['default_model'] as Map));
        merged['default_model'] = dm;
      }
      // 深度比较：内容没变就不更新 data，避免触发 effect(_writeFile)
      // 进而导致 写文件 → FileWatcher → _load → 写文件 的死循环
      if (data.value == merged) return;
      data.value = merged;
    } catch (_) {
      // JSON 解析失败：首次加载用默认值，后续保持现有 data 不变
      if (data.value.isEmpty) {
        data.value = _defaultConfig();
      }
    }
  }

  int _lastWriteMs = 0;

  void _writeFile() {
    final file = File(configPath);
    final content =
        '${const JsonEncoder.withIndent('  ').convert(data.value)}\n';
    if (file.existsSync()) {
      try {
        final existing = file.readAsStringSync();
        if (existing == content) return;
        // 文件内容不同，但若当前文件 JSON 不合法就不覆盖，
        // 防止用户编辑器里正在编辑/文件损坏时被重置
        jsonDecode(existing);
      } catch (_) {
        return;
      }
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
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
