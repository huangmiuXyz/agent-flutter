/// 技能列表页 — 展示所有已发现的技能。
///
/// 结构和 [McpServerListPage] 一致：
/// - 按已启用/已禁用分组
/// - 每行显示技能名、描述、来源标签、开关
/// - 顶部有 "重新扫描" 和 "配置文件" 按钮
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/skills/models/skill_info.dart';
import 'package:agent/store/config_store.dart';
import 'package:agent/utils/file_utils.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/list/app_big_list.dart';
import 'package:agent/widgets/switch/app_switch.dart';

/// 技能列表页。
class SkillListPage extends HookWidget {
  final ValueChanged<SkillInfo> onSkillTap;
  final VoidCallback? onRescan;
  final List<SkillInfo> skills;

  const SkillListPage({
    super.key,
    required this.onSkillTap,
    this.onRescan,
    required this.skills,
  });

  @override
  Widget build(BuildContext context) {
    final store = ConfigStore.instance;
    // 订阅 data 信号，确保开关后立即重建
    final states = store.loadSkillStates(useExistingSignal(store.data).value);
    final merged = skills.map((s) => s.copyWith(
      enabled: states[s.id] ?? s.enabled,
    )).toList();
    final enabled = merged.where((s) => s.enabled).toList();
    final disabled = merged.where((s) => !s.enabled).toList();
    final total = skills.length;

    final groups = <Widget>[];
    if (enabled.isNotEmpty) {
      groups.add(
        AppBigGroup(
          label: '已启用',
          children: [
            for (final s in enabled)
              _SkillRow(
                skill: s,
                onTap: () => onSkillTap(s),
              ),
          ],
        ),
      );
    }
    if (disabled.isNotEmpty) {
      groups.add(
        AppBigGroup(
          label: '已禁用',
          children: [
            for (final s in disabled)
              _SkillRow(
                skill: s,
                onTap: () => onSkillTap(s),
              ),
          ],
        ),
      );
    }

    return ContentFrame(
      child: AppBigList(
        key: ValueKey('skill_list_${skills.length}'),
        count: total,
        countLabel: '个技能',
        showSearch: false,
        actions: [
          AppPrimaryButton(
            text: '重新扫描',
            size: ButtonSize.sm,
            onPressed: onRescan,
          ),
          const SizedBox(width: 8),
          AppSecondaryButton(
            text: '配置文件',
            icon: 'fileCode',
            size: ButtonSize.sm,
            onPressed: () => openFile(store.configPath),
          ),
        ],
        emptyState: AppBigEmpty(
          icon: 'puzzle',
          title: '暂无技能',
          hint: '点击"重新扫描"发现项目中的技能文件。',
        ),
        children: groups,
      ),
    );
  }
}

class _SkillRow extends HookWidget {
  final SkillInfo skill;
  final VoidCallback onTap;

  const _SkillRow({
    required this.skill,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 描述末尾附加来源标签
    final desc =
        '${skill.description}  ·  ${skill.source.name}  ·  ${skill.scope == "global" ? "全局" : "项目"}';

    return AppBigRow(
      name: skill.name,
      description: desc,
      icon: 'puzzle',
      dot: true,
      dotColor: skill.enabled ? null : Colors.transparent,
      clickable: true,
      onTap: onTap,
      actions: [
        AppSwitch(
          value: skill.enabled,
          onChanged: (v) {
            ConfigStore.instance.updateSkills((map) {
              map[skill.id] = v;
            });
          },
          size: SwitchSize.sm,
        ),
      ],
    );
  }
}
