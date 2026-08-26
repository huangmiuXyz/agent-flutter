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
    // 最近使用的工作目录历史（最近的在最前，供输入栏快捷选择）
    'work_dir_history': <String>[],
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

  /// 最近使用工作目录的历史记录（最近的在最前）
  late final workDirHistory = computed<List<String>>(() {
    final list = data.value['work_dir_history'];
    return list is List ? list.whereType<String>().toList() : const [];
  });

  /// 历史记录最多保留条数。
  static const int workDirHistoryLimit = 10;

  /// 把 [path] 置顶写入历史列表（去重、超出上限丢弃最旧记录）。
  static List<String> _bumpHistory(List<String> history, String path) {
    final list = history.toList()
      ..remove(path)
      ..insert(0, path);
    if (list.length > workDirHistoryLimit) {
      list.removeRange(workDirHistoryLimit, list.length);
    }
    return list;
  }

  /// 更新全局工作目录，并写入历史。
  void updateWorkDir(String path) {
    final normalized = path.replaceAll('\\', '/');
    mutate((data) {
      data['work_dir'] = normalized;
      data['work_dir_history'] = _bumpHistory(
        workDirHistory.value,
        normalized,
      );
    });
  }

  /// 移动端：work_dir 未设置时落到应用私有 workspace 目录。
  ///
  /// Android 上 Rust 文件工具只能访问应用私有目录，默认工作目录保证
  /// read_file/apply_patch/grep 开箱可用；不写入历史（非用户主动选择）。
  void ensureMobileDefaultWorkDir() {
    if (workDir.value.isNotEmpty) return;
    final dir = defaultMobileWorkDir();
    try {
      Directory(dir).createSync(recursive: true);
    } catch (_) {
      return;
    }
    mutate((data) => data['work_dir'] = dir);
  }

  /// 仅把 [path] 记入历史（不改全局 work_dir；
  /// 用于工作目录写入智能体自身配置的场景）。
  void recordWorkDirHistory(String path) {
    final normalized = path.replaceAll('\\', '/');
    mutate((data) {
      data['work_dir_history'] = _bumpHistory(
        workDirHistory.value,
        normalized,
      );
    });
  }

  /// 从历史记录中删除一个工作目录；若删除的正是当前 work_dir 则同时清空当前值。
  void removeWorkDirHistory(String path) {
    final normalized = path.replaceAll('\\', '/');
    mutate((data) {
      final history = workDirHistory.value.toList()..remove(normalized);
      data['work_dir_history'] = history;
      if (data['work_dir'] == normalized) {
        data['work_dir'] = '';
      }
    });
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
