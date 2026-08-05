/// config_store — 全局配置文件（config.json）状态管理
library;

import 'dart:io';

import 'package:signals/signals.dart';

import 'package:agent/features/settings/models/mcp_server_info.dart';
import 'package:agent/store/file_signal_store.dart';
import 'package:agent/utils/platform_dirs.dart';

/// 全局配置 Store — 基于 [JsonFileSignalStore]：
/// 加载/写文件/外部监听由基类提供，这里只保留配置语义（类型化更新、衍生信号）。
class ConfigStore extends JsonFileSignalStore {
  static final instance = ConfigStore._();
  ConfigStore._() : super(_resolveConfigPath()) {
    dbPath = _resolveDbPath();
  }

  /// config.json 路径（兼容旧字段名）。
  String get configPath => path;

  /// SQLite DB 路径。
  late final String dbPath;

  // ── 默认配置（文件不存在或缺少字段时使用）──

  @override
  Map<String, dynamic> defaults() => {
    'provider': <String>[],
    'default_model': {'provider': '', 'model': ''},
    'mcpServers': <Map<String, dynamic>>[],
    'skills': <String, dynamic>{},
    'work_dir': '',
    // 最近选中的智能体 ID（空字符串 = 未设置，回退全局智能体）
    'current_agent': '',
  };

  /// 与默认值合并，default_model 也要合并子键。
  @override
  Map<String, dynamic> mergeDefaults(Map<String, dynamic> raw) {
    final merged = Map<String, dynamic>.from(defaults());
    merged.addAll(raw);
    if (raw['default_model'] is Map) {
      final dm = Map<String, dynamic>.from(defaults()['default_model'] as Map);
      dm.addAll(Map<String, dynamic>.from(raw['default_model'] as Map));
      merged['default_model'] = dm;
    }
    return merged;
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

  /// 工作目录，空字符串表示未设置
  late final workDir = computed<String>(() {
    return data.value['work_dir'] as String? ?? '';
  });

  /// 更新工作目录
  void updateWorkDir(String path) {
    mutate((data) => data['work_dir'] = path);
  }

  /// 持久化的最近选中智能体 ID，空字符串表示未设置（回退全局）
  late final persistedAgentId = computed<String>(() {
    return data.value['current_agent'] as String? ?? '';
  });

  /// 更新最近选中的智能体 ID（与模型切换一样写回 config.json）
  void updateCurrentAgent(String id) {
    mutate((data) => data['current_agent'] = id);
  }

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

  // ── 路径解析 ──

  static bool _inProjectDir() {
    return File('./config.json').existsSync() ||
        File('./pubspec.yaml').existsSync() ||
        Directory('./data').existsSync();
  }

  static String _resolveConfigPath() {
    const compileEnv = String.fromEnvironment('CONFIG_PATH');
    if (compileEnv.isNotEmpty) return compileEnv;

    final runtimeEnv = Platform.environment['AGENT_CONFIG_PATH'];
    if (runtimeEnv != null && runtimeEnv.isNotEmpty) return runtimeEnv;

    if (_inProjectDir()) return '../agent-flutter-cli/config.json';

    return appDataDir(['agent', 'config.json']);
  }

  static String _resolveDbPath() {
    const compileEnv = String.fromEnvironment('DB_PATH');
    if (compileEnv.isNotEmpty) return compileEnv;

    final runtimeEnv = Platform.environment['AGENT_DB_PATH'];
    if (runtimeEnv != null && runtimeEnv.isNotEmpty) return runtimeEnv;

    if (_inProjectDir()) return '../agent-flutter-cli/data/data';

    return appDataDir(['agent', 'data', 'data']);
  }
}
