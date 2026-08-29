/// 内置工具的参数专属渲染组件 — 替代展开区的原始 JSON 文本。
///
/// 三类基础原语组合出各工具的展开视图：
/// - [ToolMonoValueRow] — 图标 + 等宽单值（路径 / glob / 正则 / id）
/// - [ToolArgCaptions]  — 次要参数键值对（行区间 / 工作目录 / 超时等）
/// - [ToolTaskBlock]    — 长文本块（子智能体任务 / 终端输入）
/// 命令类工具（shell_command / simulated_terminal）直接复用聊天代码块
/// [CodeBlockView]（深色容器 + bash 高亮 + 复制按钮）。
///
/// 流式期间 arguments 是不断增长的半截 JSON，各组件在 build 时经
/// [extractToolArgs] 容错解析：字符串参数（路径/命令）随流式渐进显示，
/// 数字参数等终结后才出现（避免闪现错误值）。参数体量小（路径/命令级），
/// 每次重建全量重解析即可；apply_patch 的大补丁不走本文件，
/// 由 [ChatDiffBlock] 内部增量提取。
library;

import 'package:flutter/material.dart';

import 'package:re_highlight/languages/bash.dart';

import 'package:agent/features/chat/custom_tools_render/tool_args_extractor.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/code_block_view.dart';

// ── 基础原语 ───────────────────────────────────────────────────────────────

/// 图标 + 等宽单值行：路径 / glob / 正则 / id 等标量参数的行内样式
class ToolMonoValueRow extends StatelessWidget {
  const ToolMonoValueRow({
    super.key,
    required this.iconName,
    required this.value,
  });

  /// 参数语义图标（AppIcon 注册名）
  final String iconName;

  /// 参数值（等宽字体展示，可换行、可选中复制）
  final String value;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: custom.colors.panelElevated,
        borderRadius: custom.radii.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AppIcon(
              iconName,
              size: 12,
              color: custom.colors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontFamily: custom.typography.fontFamily ?? kDefaultFontFamily,
                fontSize: custom.typography.captionSize,
                height: 18 / custom.typography.captionSize,
                color: custom.colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 次要参数键值对平铺：`(标签, 值)` 列表自动换行排列
class ToolArgCaptions extends StatelessWidget {
  const ToolArgCaptions({super.key, required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final custom = CustomTheme.of(context);
    final caption = custom.typography.captionSize;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final (label, value) in items)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label ',
                  style: TextStyle(
                    fontSize: caption,
                    color: custom.colors.textDisabled,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: caption,
                    color: custom.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 长文本参数块：子智能体任务描述 / 终端输入原文
class ToolTaskBlock extends StatelessWidget {
  const ToolTaskBlock({super.key, required this.text, this.mono = false});

  final String text;

  /// 等宽字体（终端输入等代码语义文本）；默认 UI 字体（自然语言任务）
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(custom.spacing.sm),
      decoration: BoxDecoration(
        borderRadius: custom.radii.sm,
        border: Border.all(color: custom.colors.cardBorder),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          fontFamily: mono
              ? custom.typography.fontFamily ?? kDefaultFontFamily
              : null,
          fontSize: custom.typography.captionSize,
          height: 18 / custom.typography.captionSize,
          color: custom.colors.textPrimary,
        ),
      ),
    );
  }
}

/// 通用骨架：主值行 + 可选说明行，统一列布局与间距
class _ToolArgsView extends StatelessWidget {
  const _ToolArgsView({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) SizedBox(height: custom.spacing.xs),
          child,
        ],
      ],
    );
  }
}

/// 主值为空（流式参数尚未到达）时不渲染任何内容
Widget _emptyIfBlank(String value, Widget Function() build) {
  return value.isEmpty ? const SizedBox.shrink() : build();
}

// ── 各工具视图 ─────────────────────────────────────────────────────────────

/// `read_file` — 目标文件 + 行区间/行数上限
class ReadFileArgsView extends StatelessWidget {
  const ReadFileArgsView({super.key, required this.rawArguments});

  final String rawArguments;

  @override
  Widget build(BuildContext context) {
    final args = extractToolArgs(rawArguments);
    final path = args.str('path') ?? '';
    return _emptyIfBlank(path, () {
      final captions = <(String, String)>[];
      final start = args.intOf('start_line');
      final end = args.intOf('end_line');
      if (start != null || end != null) {
        captions.add(('行区间', '${start ?? 1} - ${end ?? '末尾'}'));
      }
      final maxLines = args.intOf('max_lines');
      if (maxLines != null) {
        captions.add(('最多行数', '$maxLines'));
      }
      return _ToolArgsView(
        children: [
          ToolMonoValueRow(iconName: 'file', value: path),
          ToolArgCaptions(items: captions),
        ],
      );
    });
  }
}

/// `grep` — 正则表达式 + 目录 / glob 限定 / 大小写 / 分页偏移
class GrepArgsView extends StatelessWidget {
  const GrepArgsView({super.key, required this.rawArguments});

  final String rawArguments;

  @override
  Widget build(BuildContext context) {
    final args = extractToolArgs(rawArguments);
    final regex = args.str('regex') ?? '';
    return _emptyIfBlank(regex, () {
      final captions = <(String, String)>[
        if ((args.str('path') ?? '').isNotEmpty) ('目录', args.str('path')!),
        if ((args.str('include_pattern') ?? '').isNotEmpty)
          ('文件匹配', args.str('include_pattern')!),
        if (args.boolean('case_sensitive') == true) ('大小写', '敏感'),
        if (args.intOf('offset') != null) ('偏移', '${args.intOf('offset')}'),
      ];
      return _ToolArgsView(
        children: [
          ToolMonoValueRow(iconName: 'textSearch', value: regex),
          ToolArgCaptions(items: captions),
        ],
      );
    });
  }
}

/// `find_path` — glob 模式 + 搜索根目录 / 分页偏移
class FindPathArgsView extends StatelessWidget {
  const FindPathArgsView({super.key, required this.rawArguments});

  final String rawArguments;

  @override
  Widget build(BuildContext context) {
    final args = extractToolArgs(rawArguments);
    final glob = args.str('glob') ?? '';
    return _emptyIfBlank(glob, () {
      final captions = <(String, String)>[
        if ((args.str('path') ?? '').isNotEmpty) ('目录', args.str('path')!),
        if (args.intOf('offset') != null) ('偏移', '${args.intOf('offset')}'),
      ];
      return _ToolArgsView(
        children: [
          ToolMonoValueRow(iconName: 'fileSearch', value: glob),
          ToolArgCaptions(items: captions),
        ],
      );
    });
  }
}

/// `list_directory` — 目标目录
class ListDirectoryArgsView extends StatelessWidget {
  const ListDirectoryArgsView({super.key, required this.rawArguments});

  final String rawArguments;

  @override
  Widget build(BuildContext context) {
    final args = extractToolArgs(rawArguments);
    final path = args.str('path') ?? '';
    return _emptyIfBlank(
      path,
      () => _ToolArgsView(
        children: [ToolMonoValueRow(iconName: 'folderTree', value: path)],
      ),
    );
  }
}

/// `load_skill` — 技能 id
class LoadSkillArgsView extends StatelessWidget {
  const LoadSkillArgsView({super.key, required this.rawArguments});

  final String rawArguments;

  @override
  Widget build(BuildContext context) {
    final args = extractToolArgs(rawArguments);
    final skillId = args.str('skill_id') ?? '';
    return _emptyIfBlank(
      skillId,
      () => _ToolArgsView(
        children: [ToolMonoValueRow(iconName: 'bookOpen', value: skillId)],
      ),
    );
  }
}

/// `shell_command` / `simulated_terminal` — 命令代码块 + 工作目录/超时/终端 id
class ShellCommandArgsView extends StatelessWidget {
  const ShellCommandArgsView({
    super.key,
    required this.rawArguments,
    required this.label,
  });

  final String rawArguments;

  /// 代码块头部标签（shell / terminal）
  final String label;

  @override
  Widget build(BuildContext context) {
    final args = extractToolArgs(rawArguments);
    final command = args.str('command') ?? '';
    return _emptyIfBlank(command, () {
      final captions = <(String, String)>[
        if ((args.str('workdir') ?? '').isNotEmpty)
          ('工作目录', args.str('workdir')!),
        if (args.intOf('timeout_ms') != null)
          ('超时', '${args.intOf('timeout_ms')} ms'),
        if ((args.str('terminal_id') ?? '').isNotEmpty)
          ('终端', args.str('terminal_id')!),
      ];
      return _ToolArgsView(
        children: [
          CodeBlockView(code: command, language: langBash, label: label),
          ToolArgCaptions(items: captions),
        ],
      );
    });
  }
}

/// `terminal_send_input` — 目标终端 + 输入原文（等宽块）
class TerminalInputArgsView extends StatelessWidget {
  const TerminalInputArgsView({super.key, required this.rawArguments});

  final String rawArguments;

  @override
  Widget build(BuildContext context) {
    final args = extractToolArgs(rawArguments);
    final text = args.str('text') ?? '';
    return _emptyIfBlank(text, () {
      final captions = <(String, String)>[
        if ((args.str('terminal_id') ?? '').isNotEmpty)
          ('终端', args.str('terminal_id')!),
        if (args.boolean('press_enter') == true) ('回车', '是'),
      ];
      return _ToolArgsView(
        children: [
          ToolTaskBlock(text: text, mono: true),
          ToolArgCaptions(items: captions),
        ],
      );
    });
  }
}

/// `spawn_sub_agent` — 智能体 id + 任务描述 + 运行模式
class SpawnSubAgentArgsView extends StatelessWidget {
  const SpawnSubAgentArgsView({super.key, required this.rawArguments});

  final String rawArguments;

  @override
  Widget build(BuildContext context) {
    final args = extractToolArgs(rawArguments);
    final agentId = args.str('agent_id') ?? '';
    final task = args.str('task') ?? '';
    if (agentId.isEmpty && task.isEmpty) return const SizedBox.shrink();
    final mode = args.str('mode');
    return _ToolArgsView(
      children: [
        if (agentId.isNotEmpty)
          ToolMonoValueRow(iconName: 'robot', value: agentId),
        if (task.isNotEmpty) ToolTaskBlock(text: task),
        ToolArgCaptions(
          items: [if (mode != null && mode.isNotEmpty) ('模式', mode)],
        ),
      ],
    );
  }
}
