/// 智能体编辑/创建页。
///
/// 表单结构（见 docs/agent-system.md）：
/// - 基本信息（标识、名称、描述）
/// - default_model（从全局已有模型列表中选择）
/// - MCP 服务器（从全局已有 mcpServers 列表中勾选）
/// - 技能启禁（从已扫描到的全局技能中勾选）
/// - work_dir（可选）
/// - 底部操作栏：[从全局导入] [删除] [取消] [保存]
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/features/agents/models/agent_info.dart';
import 'package:agent/features/agents/store/agent_store.dart';
import 'package:agent/features/settings/models/mcp_server_info.dart';
import 'package:agent/features/skills/store/skill_store.dart';
import 'package:agent/rust_bridge/api.dart' as bridge;
import 'package:agent/store/config_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/dialog/app_dialog.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/field/app_file_path_field.dart';
import 'package:agent/widgets/select/app_multi_select.dart';
import 'package:agent/widgets/select/app_select.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 智能体编辑页。[agent] 为 null 时是创建模式。
class AgentEditPage extends HookWidget {
  /// 被编辑的智能体；null 表示创建新智能体。
  final AgentInfo? agent;

  /// 返回列表页。
  final VoidCallback onBack;

  /// 保存成功后回调（通常同 [onBack]）。
  final VoidCallback onSaved;

  const AgentEditPage({
    super.key,
    this.agent,
    required this.onBack,
    required this.onSaved,
  });

  bool get isCreate => agent == null;
  bool get isGlobal => agent?.isGlobal ?? false;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final configStore = ConfigStore.instance;

    // ── 表单状态 ──
    final idController = useTextEditingController(
      text: isCreate ? '' : agent!.id,
    );
    final nameController = useTextEditingController(
      text: isCreate ? '' : agent!.name,
    );
    final descController = useTextEditingController(
      text: isCreate ? '' : agent!.description,
    );
    final workDirController = useTextEditingController();
    final selectedProvider = useState<String?>(null);
    final selectedModel = useState<String?>(null);
    final selectedMcp = useState<Set<String>>({});
    final selectedSkills = useState<Set<String>>({});
    final enabled = useState(true);
    final saving = useState(false);
    final loaded = useState(false);

    // ── 全局可选项：provider → models 映射（来自全局 language_models）──
    final providerModels = useMemoized(() {
      final result = <String, List<String>>{};
      final lm = configStore.data.value['language_models'];
      if (lm is Map<String, dynamic>) {
        for (final proto in lm.values) {
          if (proto is! Map<String, dynamic>) continue;
          for (final entry in proto.entries) {
            final cfg = entry.value;
            if (cfg is! Map<String, dynamic>) continue;
            final raw = cfg['available_models'] as List<dynamic>?;
            if (raw == null) continue;
            final names = raw
                .map((e) => e is Map ? e['name']?.toString() : e.toString())
                .whereType<String>()
                .toList();
            result.putIfAbsent(entry.key, () => []).addAll(names);
          }
        }
      }
      return result;
    }, [configStore.data.value]);

    // ── 全局 MCP 服务器列表 ──
    final mcpServers = useMemoized(
      () => loadMcpServers(configStore.data.value),
      [configStore.data.value],
    );

    // ── 全局技能列表（为空时触发一次扫描）──
    final skills = SkillStore.instance.skills.value.values.toList();
    useEffect(() {
      if (SkillStore.instance.skills.value.isEmpty) {
        bridge.scanGlobalSkills().then((discovered) {
          SkillStore.instance.load(discovered);
        });
      }
      return null;
    }, const []);

    // ── 编辑模式：读取现有配置填充表单 ──
    useEffect(() {
      if (isCreate || loaded.value) return null;
      loaded.value = true;
      bridge.readAgentConfig(configPath: agent!.configPath).then((raw) {
        try {
          final cfg = jsonDecode(raw) as Map<String, dynamic>;
          nameController.text = cfg['name'] as String? ?? agent!.name;
          descController.text = cfg['description'] as String? ?? '';
          enabled.value =
              cfg['enable'] as bool? ?? false;
          workDirController.text = cfg['work_dir'] as String? ?? '';
          final dm = cfg['default_model'];
          if (dm is Map<String, dynamic>) {
            selectedProvider.value = dm['provider'] as String?;
            selectedModel.value = dm['model'] as String?;
          }
          final mcp = cfg['mcpServers'];
          if (mcp is Map<String, dynamic>) {
            selectedMcp.value = mcp.keys.toSet();
          }
          final sk = cfg['skills'];
          if (sk is Map<String, dynamic>) {
            selectedSkills.value = sk.entries
                .where((e) {
                  final v = e.value;
                  return v is Map && v['enabled'] == true;
                })
                .map((e) => e.key)
                .toSet();
          }
        } catch (_) {
          // 配置解析失败：保持默认空表单，用户可重建
        }
      });
      return null;
    }, const []);



    // ── 保存 ──
    Future<void> save() async {
      final name = nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请填写名称')));
        return;
      }
      final id = idController.text.trim();
      if (isCreate) {
        if (id.isEmpty ||
            id == kGlobalAgentId ||
            id.contains(RegExp(r'[\\/:*?"<>|]'))) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('标识无效：不能为空、不能为 全局、不能包含路径字符')));
          return;
        }
      }

      saving.value = true;
      try {
        final global = configStore.data.value;

        // 编辑模式以现有配置为底，保留 UI 不管理的字段；创建模式从空开始
        Map<String, dynamic> cfg = {};
        if (!isCreate) {
          try {
            final raw = await bridge.readAgentConfig(
              configPath: agent!.configPath,
            );
            cfg = jsonDecode(raw) as Map<String, dynamic>;
          } catch (_) {}
        }

        if (isGlobal) {
          // 全局智能体：只更新 default_model 和 work_dir
          if (selectedProvider.value != null && selectedModel.value != null) {
            cfg['default_model'] = {
              'provider': selectedProvider.value,
              'model': selectedModel.value,
            };
          } else {
            cfg.remove('default_model');
          }
          final workDir = workDirController.text.trim();
          if (workDir.isNotEmpty) {
            cfg['work_dir'] = workDir;
          } else {
            cfg.remove('work_dir');
          }
        } else {
          cfg['name'] = name;
          cfg['description'] = descController.text.trim();
          if (!enabled.value) {
            cfg['enable'] = false;
          } else {
            cfg['enable'] = true;
          }
          if (selectedProvider.value != null && selectedModel.value != null) {
            cfg['default_model'] = {
              'provider': selectedProvider.value,
              'model': selectedModel.value,
            };
          } else {
            cfg.remove('default_model');
          }
          final workDir = workDirController.text.trim();
          if (workDir.isNotEmpty) {
            cfg['work_dir'] = workDir;
          } else {
            cfg.remove('work_dir');
          }

          // MCP 服务器：从全局配置中拷贝勾选项的完整定义
          final globalMcp =
              global['mcpServers'] as Map<String, dynamic>? ?? {};
          cfg['mcpServers'] = {
            for (final name in selectedMcp.value)
              if (globalMcp.containsKey(name)) name: globalMcp[name],
          };

          // 技能：只写入启用的
          cfg['skills'] = {
            for (final id in selectedSkills.value) id: {'enabled': true},
          };

          // 自包含：拷贝 provider 列表与模型凭证（聊天时按此配置寻址 LLM）
          cfg['provider'] = global['provider'] ?? <String>[];
          cfg['language_models'] =
              global['language_models'] ?? <String, dynamic>{};
        }

        final json = '${const JsonEncoder.withIndent('  ').convert(cfg)}\n';

        if (isCreate) {
          await bridge.createAgent(
            configPath: configStore.configPath,
            agentId: id,
            configJson: json,
          );
        } else {
          await bridge.writeAgentConfig(
            configPath: agent!.configPath,
            configJson: json,
          );
        }

        await AgentStore.instance.refresh();
        if (isGlobal) {
          configStore.reload();
        }
        onSaved();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
        }
      } finally {
        saving.value = false;
      }
    }

    final providerOptions = [
      for (final p in providerModels.keys)
        AppSelectOption(value: p, label: p),
    ];
    final modelOptions = [
      for (final m in providerModels[selectedProvider.value] ?? const <String>[])
        AppSelectOption<String>(value: m, label: m),
    ];

    return ContentFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBreadcrumb(
            items: [
              AppBreadcrumbItem('设置', onTap: () {}),
              AppBreadcrumbItem('智能体', onTap: onBack),
              AppBreadcrumbItem(isCreate ? '创建' : agent!.name),
            ],
          ),
          SizedBox(height: custom.spacing.lg),

          if (!isGlobal) ...[
            // ── 基本信息 ──
            AppText('基本信息', variant: AppTextVariant.subtitle),
            SizedBox(height: custom.spacing.sm),
            if (isCreate) ...[
              AppField(
                label: '标识（文件夹名）',
                placeholder: '如 code-reviewer，创建后不可修改',
                controller: idController,
              ),
              SizedBox(height: custom.spacing.sm),
            ],
            AppField(
              label: '名称',
              placeholder: '显示名称（必填）',
              controller: nameController,
            ),
            SizedBox(height: custom.spacing.sm),
            AppField(
              label: '描述',
              placeholder: '这个智能体擅长什么？',
              controller: descController,
            ),
            SizedBox(height: custom.spacing.lg),
          ],

          // ── 默认模型 ──
          AppText('默认模型', variant: AppTextVariant.subtitle),
          SizedBox(height: custom.spacing.sm),
          AppSelect<String>(
            label: '提供商',
            placeholder: '从全局已有模型中选择',
            value: selectedProvider.value,
            options: providerOptions,
            onChanged: (v) {
              selectedProvider.value = v;
              selectedModel.value = null;
            },
          ),
          SizedBox(height: custom.spacing.sm),
          AppSelect<String>(
            label: '模型',
            placeholder: selectedProvider.value == null ? '先选择提供商' : '选择模型',
            value: selectedModel.value,
            options: modelOptions,
            disabled: selectedProvider.value == null,
            onChanged: (v) => selectedModel.value = v,
          ),
          SizedBox(height: custom.spacing.lg),

          if (!isGlobal) ...[
            // ── MCP 服务器 ──
            AppText('MCP 服务器', variant: AppTextVariant.subtitle),
            SizedBox(height: custom.spacing.sm),
            AppMultiSelect<String>(
              label: '启用的服务器',
              placeholder: '从全局 mcpServers 中勾选',
              value: selectedMcp.value,
              options: [
                for (final s in mcpServers)
                  AppMultiSelectOption(value: s.name, label: s.name),
              ],
              onChanged: (v) => selectedMcp.value = v,
            ),
            SizedBox(height: custom.spacing.lg),

            // ── 技能 ──
            AppText('技能', variant: AppTextVariant.subtitle),
            SizedBox(height: custom.spacing.sm),
            AppMultiSelect<String>(
              label: '启用的技能',
              placeholder: '从全局已扫描技能中勾选',
              value: selectedSkills.value,
              options: [
                for (final s in skills)
                  AppMultiSelectOption(value: s.id, label: s.name),
              ],
              onChanged: (v) => selectedSkills.value = v,
            ),
            SizedBox(height: custom.spacing.lg),
          ],

          // ── 工作目录 ──
          AppText('工作目录', variant: AppTextVariant.subtitle),
          SizedBox(height: custom.spacing.sm),
          AppFilePathField(
            controller: workDirController,
            label: 'work_dir（可选）',
            placeholder: '留空则跟随全局配置',
          ),
          SizedBox(height: custom.spacing.lg),

          // ── 底部操作栏 ──
          Row(
            children: [
              const Spacer(),
              if (!isCreate && !isGlobal)
                AppSecondaryButton(
                  text: '删除',
                  size: ButtonSize.sm,
                  onPressed: () => _handleDelete(context),
                ),
              if (!isCreate && !isGlobal) SizedBox(width: custom.spacing.xs),
              AppSecondaryButton(
                text: '取消',
                size: ButtonSize.sm,
                onPressed: onBack,
              ),
              SizedBox(width: custom.spacing.xs),
              AppPrimaryButton(
                text: saving.value ? '保存中...' : '保存',
                size: ButtonSize.sm,
                disabled: saving.value,
                onPressed: save,
              ),
            ],
          ),
          SizedBox(height: custom.spacing.lg),
        ],
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await AppDialog.show(
      context: context,
      title: '确认删除',
      okText: '删除',
      child: AppText('确定要删除智能体「${agent!.name}」吗？\n\n此操作不可撤销。'),
    );
    if (confirmed != true) return;

    try {
      await bridge.deleteAgent(agentDir: agent!.directoryPath);
      await AgentStore.instance.refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已删除')));
        onSaved();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }
}
