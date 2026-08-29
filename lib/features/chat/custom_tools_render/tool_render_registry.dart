/// 内置工具自定义渲染注册表 — 工具名 → 专属图标 / 标题 / 参数渲染。
///
/// 聊天中的工具调用卡片默认是「工具调用: `<name>`」标题 + 原始 JSON 参数；
/// 内置工具在此注册 [ToolRenderSpec] 后，卡片头部显示带关键参数的
/// 人话标题（如「读取文件 src/main.rs」），展开区以结构化组件替代 JSON。
///
/// 注册清单与 Rust 端 `builtin_tools::list_options` 的内置工具对齐：
/// 后端工具（load_skill / apply_patch / read_file / grep / find_path /
/// list_directory / shell_command / spawn_sub_agent）与前端工具
/// （simulated_terminal / terminal_send_input）。apply_patch 的大补丁
/// diff 渲染（[ChatDiffBlock]）也在此统一注册。
/// 未注册的工具（MCP 等外部工具）返回 null，调用方回落通用渲染。
library;

import 'package:flutter/material.dart';

import 'package:agent/features/chat/custom_tools_render/builtin_tool_renders.dart';
import 'package:agent/features/chat/custom_tools_render/builtin_tool_results.dart';
import 'package:agent/features/chat/custom_tools_render/chat_diff_block.dart';
import 'package:agent/features/chat/custom_tools_render/tool_args_extractor.dart';
import 'package:agent/theme/app_colors.dart';

/// 单个内置工具的渲染描述
class ToolRenderSpec {
  const ToolRenderSpec({
    required this.iconName,
    required this.title,
    this.titleColor,
    this.argumentsBuilder,
    this.resultBuilder,
  });

  /// 卡片头部图标（AppIcon 注册名）
  final String iconName;

  /// 卡片标题：从（流式期间可能不完整的）参数中提取关键信息拼入；
  /// 主值未到达时返回纯动作文案。超长内容由头部行省略号截断
  final String Function(ToolArgs args) title;

  /// 标题颜色（缺省 accent）
  final Color Function(AppColors colors)? titleColor;

  /// 展开区参数渲染：接收原始 arguments 字符串（流式半截 JSON），
  /// 组件内部经 [extractToolArgs] 容错解析；缺省保留 JSON 文本渲染
  final Widget Function(BuildContext context, String rawArguments)?
  argumentsBuilder;

  /// 展开区结果渲染：接收原始 arguments 与原始 tool_result 文本，
  /// 组件内部按工具结果结构解析（不匹配时自行回退通用文本渲染）；
  /// 缺省保留通用文本渲染（ANSI 彩色段落）
  final Widget Function(
    BuildContext context,
    String rawArguments,
    String rawResult,
  )?
  resultBuilder;
}

/// 标题文案：动作词 + 主参数值（空值时只显示动作词）
String _titleWith(String action, String? value) {
  if (value == null || value.isEmpty) return action;
  return '$action $value';
}

/// 命令取首行作为标题（多行脚本只展示入口一行）
String? _firstLine(String? value) {
  if (value == null || value.isEmpty) return null;
  return value.split('\n').first;
}

final Map<String, ToolRenderSpec> _specs = {
  // diff 代码块渲染：patch 的增量提取在 ChatDiffBlock 内部完成
  // （流式逐行渲染），此处不解析参数；结果为操作摘要行
  'apply_patch': ToolRenderSpec(
    iconName: 'fileCode',
    title: (_) => '应用补丁',
    titleColor: (colors) => colors.success,
    argumentsBuilder: (_, raw) => ChatDiffBlock.arguments(rawArguments: raw),
    resultBuilder: (_, _, result) => PatchResultView(rawResult: result),
  ),
  'read_file': ToolRenderSpec(
    iconName: 'file',
    title: (args) => _titleWith('读取文件', args.str('path')),
    argumentsBuilder: (_, raw) => ReadFileArgsView(rawArguments: raw),
    resultBuilder: (_, args, result) =>
        ReadFileResultView(rawArguments: args, rawResult: result),
  ),
  'grep': ToolRenderSpec(
    iconName: 'textSearch',
    title: (args) => _titleWith('搜索内容', args.str('regex')),
    argumentsBuilder: (_, raw) => GrepArgsView(rawArguments: raw),
    resultBuilder: (_, _, result) => GrepResultView(rawResult: result),
  ),
  'find_path': ToolRenderSpec(
    iconName: 'fileSearch',
    title: (args) => _titleWith('查找文件', args.str('glob')),
    argumentsBuilder: (_, raw) => FindPathArgsView(rawArguments: raw),
    resultBuilder: (_, _, result) => FindPathResultView(rawResult: result),
  ),
  'list_directory': ToolRenderSpec(
    iconName: 'folderTree',
    title: (args) => _titleWith('列出目录', args.str('path')),
    argumentsBuilder: (_, raw) => ListDirectoryArgsView(rawArguments: raw),
    resultBuilder: (_, _, result) => ListDirResultView(rawResult: result),
  ),
  'shell_command': ToolRenderSpec(
    iconName: 'terminalSquare',
    title: (args) => _titleWith('执行命令', _firstLine(args.str('command'))),
    argumentsBuilder: (_, raw) =>
        ShellCommandArgsView(rawArguments: raw, label: 'shell'),
    resultBuilder: (_, _, result) => ShellResultView(rawResult: result),
  ),
  'load_skill': ToolRenderSpec(
    iconName: 'bookOpen',
    title: (args) => _titleWith('加载技能', args.str('skill_id')),
    argumentsBuilder: (_, raw) => LoadSkillArgsView(rawArguments: raw),
    resultBuilder: (_, _, result) => SkillResultView(rawResult: result),
  ),
  'spawn_sub_agent': ToolRenderSpec(
    iconName: 'robot',
    title: (args) => _titleWith('运行子智能体', args.str('agent_id')),
    argumentsBuilder: (_, raw) => SpawnSubAgentArgsView(rawArguments: raw),
    resultBuilder: (_, _, result) => SubAgentResultView(rawResult: result),
  ),
  // 前端工具（Flutter 注册）
  'simulated_terminal': ToolRenderSpec(
    iconName: 'terminal',
    title: (args) => _titleWith('终端执行', _firstLine(args.str('command'))),
    argumentsBuilder: (_, raw) =>
        ShellCommandArgsView(rawArguments: raw, label: 'terminal'),
    resultBuilder: (_, _, result) =>
        SimulatedTerminalResultView(rawResult: result),
  ),
  'terminal_send_input': ToolRenderSpec(
    iconName: 'textCursorInput',
    title: (args) => _titleWith('终端输入', _firstLine(args.str('text'))),
    argumentsBuilder: (_, raw) => TerminalInputArgsView(rawArguments: raw),
    resultBuilder: (_, _, result) => TerminalInputResultView(rawResult: result),
  ),
};

/// 按工具名取渲染描述；未注册（MCP 等外部工具）返回 null
ToolRenderSpec? toolRenderSpec(String? toolName) {
  if (toolName == null || toolName.isEmpty) return null;
  return _specs[toolName];
}
