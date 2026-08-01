/// 命令注册表 — 集中管理全部命令的注册、查询与搜索。
///
/// 命令集在应用启动时通过 [registerAll] 一次性注册（定义见 commands.dart），
/// 命令面板和快捷键层都从这里读取。enabled 状态不在这里缓存，
/// 由调用方（面板）在构建时对每条命令求值，保证信号变化即时反映。
library;

import 'package:agent/features/commands/models/command_info.dart';

class CommandStore {
  static final instance = CommandStore._();
  CommandStore._();

  final Map<String, CommandInfo> _commands = {};

  /// 注册一组命令；id 重复时后者覆盖前者（应用启动时调用，幂等）。
  void registerAll(Iterable<CommandInfo> commands) {
    for (final c in commands) {
      _commands[c.id] = c;
    }
  }

  /// 按 id 查找命令。
  CommandInfo? find(String id) => _commands[id];

  /// 全部命令（注册顺序）。
  List<CommandInfo> get all => List.unmodifiable(_commands.values);

  /// 按关键词过滤命令：匹配标题、分组或 id（大小写不敏感）。
  List<CommandInfo> query(String keyword) {
    final q = keyword.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final c in all)
        if (c.title.toLowerCase().contains(q) ||
            c.id.toLowerCase().contains(q) ||
            (c.category?.toLowerCase().contains(q) ?? false))
          c,
    ];
  }
}
