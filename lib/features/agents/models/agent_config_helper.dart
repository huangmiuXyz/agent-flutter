/// 智能体配置导入辅助函数。
library;

import 'dart:convert';
import 'dart:io';

import 'package:agent/rust_bridge/api/agents.dart' as bridge;

/// 从全局 config.json 提取可选的配置片段，供创建/编辑智能体时使用。
///
/// 返回一个 map，只包含 UI 上允许用户选择的字段：
/// - default_model
/// - title_model
/// - mcpServers
/// - skills
Map<String, dynamic> extractImportableConfig(Map<String, dynamic> globalConfig) {
  final result = <String, dynamic>{};

  if (globalConfig.containsKey('default_model')) {
    result['default_model'] = globalConfig['default_model'];
  }
  if (globalConfig.containsKey('title_model')) {
    result['title_model'] = globalConfig['title_model'];
  }
  if (globalConfig.containsKey('mcpServers')) {
    result['mcpServers'] = globalConfig['mcpServers'];
  }
  if (globalConfig.containsKey('skills')) {
    result['skills'] = globalConfig['skills'];
  }

  return result;
}

/// 智能体 config.json 的读取 / 字段解析 / 序列化辅助。
///
/// 「读配置 → 取字段 → 回退」的样板在 AgentStore 与多个设置页面重复，
/// 统一收敛到这里；所有读取失败均返回 null / 默认值，由调用方决定回退。
class AgentConfigHelper {
  AgentConfigHelper._();

  /// 异步读取并解析智能体配置文件（走 Rust bridge），失败返回 null。
  static Future<Map<String, dynamic>?> readConfig(String configPath) async {
    try {
      final raw = await bridge.readAgentConfig(configPath: configPath);
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 同步读取并解析智能体配置文件（同步场景，如 [AgentStore.resolveModel]），
  /// 失败返回 null。
  static Map<String, dynamic>? readConfigSync(String configPath) {
    try {
      final raw = File(configPath).readAsStringSync();
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 取出配置中的 default_model；provider 和 model 都非空时返回，否则 null。
  static ({String provider, String model})? defaultModel(
    Map<String, dynamic> cfg,
  ) {
    final dm = cfg['default_model'];
    if (dm is Map) {
      final p = dm['provider'] as String? ?? '';
      final m = dm['model'] as String? ?? '';
      if (p.isNotEmpty && m.isNotEmpty) return (provider: p, model: m);
    }
    return null;
  }

  /// 取出配置中的 title_model；未配置时回退 default_model，均无则 null。
  static ({String provider, String model})? titleModel(
    Map<String, dynamic> cfg,
  ) {
    final explicit = explicitTitleModel(cfg);
    if (explicit != null) return explicit;
    return defaultModel(cfg);
  }

  /// 仅取出配置中显式的 title_model（不做回退），供编辑页回显：
  /// 用户未配置时显示"未设置"，而不是显示回退后的 default_model。
  static ({String provider, String model})? explicitTitleModel(
    Map<String, dynamic> cfg,
  ) {
    final tm = cfg['title_model'];
    if (tm is Map) {
      final p = tm['provider'] as String? ?? '';
      final m = tm['model'] as String? ?? '';
      if (p.isNotEmpty && m.isNotEmpty) return (provider: p, model: m);
    }
    return null;
  }

  /// 取出配置中的 work_dir，未配置返回空串。
  static String workDir(Map<String, dynamic> cfg) =>
      cfg['work_dir'] as String? ?? '';

  /// 取出配置中的 enable 开关。
  static bool enabled(Map<String, dynamic> cfg) =>
      cfg['enable'] as bool? ?? false;

  /// 取出启用的技能 id 集合（`skills: {id: {"enabled": true}}`）。
  static Set<String> enabledSkills(Map<String, dynamic> cfg) {
    final sk = cfg['skills'];
    if (sk is! Map<String, dynamic>) return {};
    return sk.entries
        .where(
          (e) => e.value is Map && (e.value as Map)['enabled'] == true,
        )
        .map((e) => e.key)
        .toSet();
  }

  /// 取出启用的内置工具 id 集合（`builtinTools: {id: {"enabled": true}}`）。
  static Set<String> enabledBuiltinTools(Map<String, dynamic> cfg) {
    final bt = cfg['builtinTools'];
    if (bt is! Map<String, dynamic>) return {};
    return bt.entries
        .where(
          (e) => e.value is Map && (e.value as Map)['enabled'] == true,
        )
        .map((e) => e.key)
        .toSet();
  }

  /// 取出工具调用轮次上限（`max_tool_call_rounds`），缺省 100，0 表示不限制。
  static int maxToolCallRounds(Map<String, dynamic> cfg) =>
      cfg['max_tool_call_rounds'] as int? ?? 100;

  /// 取出是否注入「运行环境」提示词（`injectEnvPrompt`），缺省 true。
  static bool injectEnvPrompt(Map<String, dynamic> cfg) =>
      cfg['injectEnvPrompt'] as bool? ?? true;

  /// 将配置序列化为缩进 JSON（写回配置文件用）。
  static String encode(Map<String, dynamic> cfg) =>
      '${const JsonEncoder.withIndent('  ').convert(cfg)}\n';
}
