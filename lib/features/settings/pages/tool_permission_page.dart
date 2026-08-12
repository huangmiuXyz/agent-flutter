/// 工具权限设置页 — 编辑 config.json 的 `tool_permissions.tools`。
///
/// **仅内置工具**；MCP 工具的权限保存在各自服务器配置里
/// （`mcpServers.<server>.tool_permissions.tools`，在 MCP 服务器配置页设置），
/// 不在这里出现。保存时会顺带清理顶层残留的 MCP 工具条目（工具名含 `/`）。
///
/// 每个工具一行：两态选择（允许 / 询问）。格式与 Zed 的 `tool_permissions` 一致：
///
/// ```json
/// "tool_permissions": {
///   "tools": {
///     "read_file": { "default": "ask" },
///     "delete_path": { "default": "allow" }
///   }
/// }
/// ```
///
/// `default` 只有两个持久状态：`"ask"`（每次询问，缺省）与 `"allow"`（总是允许）；
/// 拒绝只作用于本次、不落盘，因此这里没有「拒绝」选项。
///
/// 保存时直接写回 `configPath` 对应的配置文件（保留其它字段）。
/// 全局设置页与智能体编辑页共用本页（传各自的 configPath）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/features/agents/models/agent_config_helper.dart';
import 'package:agent/rust_bridge/api/agents.dart' as bridge_agents;
import 'package:agent/rust_bridge/api/builtin_tools.dart' as bridge_tools;
import 'package:agent/rust_bridge/api/types.dart' as bridge_types;
import 'package:agent/store/config_store.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/form/app_form_page.dart';
import 'package:agent/widgets/list/app_big_list.dart';
import 'package:agent/widgets/select/app_select.dart';

class ToolPermissionPage extends HookWidget {
  /// 目标配置文件（全局 config.json 或 `agents/<id>/config.json`）。
  final String configPath;

  /// 返回上一级；null = 本页为设置面板根 tab（无上级）。
  final VoidCallback? onBack;

  const ToolPermissionPage({super.key, required this.configPath, this.onBack});

  @override
  Widget build(BuildContext context) {
    final back = onBack;
    // 工具名 → default（"allow" / "ask"）
    final defaults = useState<Map<String, String>>({});
    // 内置工具名 → 描述（行内展示；MCP 等其它工具无描述）
    final builtinDescriptions = useState<Map<String, String>>({});
    final loaded = useState(false);
    // 实时保存队列：链式串行，避免快速连续修改时并发写互相覆盖
    final saveQueue = useRef<Future<void>>(Future.value());

    // ── 加载：内置工具 + 配置中已有的工具（含 MCP 工具）──
    useEffect(() {
      if (loaded.value) return null;
      loaded.value = true;

      Future.wait([
        bridge_tools.listBuiltinToolOptions(),
        AgentConfigHelper.readConfig(configPath),
      ]).then((results) {
        final options = results[0] as List<bridge_types.BuiltinToolOption>;
        final cfg = results[1] as Map<String, dynamic>?;

        final names = <String>[];
        for (final t in options) {
          names.add(t.name);
        }
        if (cfg != null) {
          // 兼容历史数据：顶层 tool_permissions 里可能有 MCP 工具条目
          // （工具名含 `/`），仅保留内置工具名（MCP 权限已迁移到服务器配置）
          final configured =
              cfg['tool_permissions']?['tools'] as Map<String, dynamic>?;
          if (configured != null) {
            for (final name in configured.keys) {
              if (!name.contains('/') && !names.contains(name)) {
                names.add(name);
              }
            }
          }
        }

        final toolDefaults = <String, String>{};
        for (final name in names) {
          final entry =
              (cfg?['tool_permissions']?['tools']
                      as Map<String, dynamic>?)?[name]
                  as Map<String, dynamic>?;
          toolDefaults[name] = (entry?['default'] as String?) ?? 'ask';
        }
        defaults.value = toolDefaults;
        builtinDescriptions.value = {
          for (final t in options) t.name: t.description,
        };
      });
      return null;
    }, const []);

    // ── 实时保存：每次选择立即写回 tool_permissions（保留其它字段），静默成功 ──
    Future<void> doSave() async {
      try {
        final existing =
            await AgentConfigHelper.readConfig(configPath) ??
            <String, dynamic>{};
        final tools = <String, dynamic>{};
        for (final name in defaults.value.keys) {
          tools[name] = {'default': defaults.value[name] ?? 'ask'};
        }
        // 清理顶层残留的 MCP 工具条目（工具名含 `/`；权限已迁移到服务器配置）
        final legacyTools =
            existing['tool_permissions']?['tools'] as Map<String, dynamic>?;
        if (legacyTools != null) {
          for (final name in legacyTools.keys) {
            if (name.contains('/')) {
              tools.remove(name);
            }
          }
        }
        existing['tool_permissions'] = {'tools': tools};
        await bridge_agents.writeAgentConfig(
          configPath: configPath,
          configJson: AgentConfigHelper.encode(existing),
        );

        // 全局配置写入后刷新内存态，其它窗口/页面同步
        if (configPath == ConfigStore.instance.configPath) {
          ConfigStore.instance.reload();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
        }
      }
    }

    void scheduleSave() {
      saveQueue.value = saveQueue.value.then((_) => doSave(), onError: (_) {});
    }

    // ── 仅内置工具（MCP 工具的权限在各自服务器配置里设置）──
    final toolNames = defaults.value.keys.toList();

    Widget row(String name) {
      return AppBigRow(
        name: name,
        mono: true,
        description: builtinDescriptions.value[name],
        actions: [
          SizedBox(
            width: 140,
            child: AppSelect<String>(
              value: defaults.value[name],
              size: FieldSize.sm,
              options: const [
                AppSelectOption(value: 'ask', label: '询问'),
                AppSelectOption(value: 'allow', label: '允许'),
              ],
              onChanged: (v) {
                if (v != null) {
                  defaults.value = {...defaults.value, name: v};
                  // 实时保存（链式串行，失败不阻断后续保存）
                  scheduleSave();
                }
              },
            ),
          ),
        ],
      );
    }

    return AppFormPage(
      showTitle: false,
      breadcrumbItems: [
        // 仅保留「设置」返回入口；不显示「工具权限」当前页项
        if (back != null) AppBreadcrumbItem('设置', onTap: back),
      ],
      title: '工具权限',
      children: [
        AppBigList(
          count: toolNames.length,
          countLabel: '个工具',
          // 头部（计数）需要 count 与 actions 同时非空才渲染，
          // 本页无头部操作按钮，传空列表占位
          actions: const [],
          children: [
            if (toolNames.isNotEmpty)
              AppBigGroup(
                label: '内置工具',
                children: [for (final name in toolNames) row(name)],
              ),
          ],
        ),
      ],
    );
  }
}
