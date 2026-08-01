/// 通用「已启用/已禁用分组」列表页组件。
///
/// 设置页的智能体 / MCP 服务器 / 技能三个列表页结构相同：
/// 按启禁状态分两组 + 顶部计数与操作按钮 + 空态展示。本组件统一外壳，
/// 行内容与开关写入逻辑由调用方通过 [rowBuilder] 提供，避免抽象变形。
library;

import 'package:flutter/material.dart';

import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/list/app_big_list.dart';

class ToggleGroupListPage<T> extends StatelessWidget {
  const ToggleGroupListPage({
    super.key,
    required this.items,
    required this.isEnabled,
    required this.rowBuilder,
    required this.countLabel,
    this.extraGroups = const [],
    this.count,
    this.actions = const [],
    this.emptyState,
  });

  /// 全部条目（组件按 [isEnabled] 自动分组成「已启用/已禁用」）。
  final List<T> items;

  /// 判定条目是否处于启用状态。
  final bool Function(T) isEnabled;

  /// 行渲染（如 [AppBigRow]），开关交互逻辑保留在调用方。
  final Widget Function(BuildContext context, T item) rowBuilder;

  /// 额外分组（如智能体列表的「全局」组），显示在启禁用两组之前。
  final List<Widget> extraGroups;

  /// 顶部计数，默认 [items.length]。
  final int? count;

  /// 计数标签（如「个智能体」）。
  final String countLabel;

  /// 顶部操作按钮（如「创建」）。
  final List<Widget> actions;

  /// 空态展示。
  final Widget? emptyState;

  @override
  Widget build(BuildContext context) {
    final enabled = items.where(isEnabled).toList();
    final disabled = items.where((i) => !isEnabled(i)).toList();

    final groups = <Widget>[
      ...extraGroups,
      if (enabled.isNotEmpty)
        AppBigGroup(
          label: '已启用',
          children: [for (final i in enabled) rowBuilder(context, i)],
        ),
      if (disabled.isNotEmpty)
        AppBigGroup(
          label: '已禁用',
          children: [for (final i in disabled) rowBuilder(context, i)],
        ),
    ];

    return ContentFrame(
      child: AppBigList(
        key: key,
        count: count ?? items.length,
        countLabel: countLabel,
        actions: actions,
        emptyState: emptyState,
        children: groups,
      ),
    );
  }
}
