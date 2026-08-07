/// 添加 MCP 服务器页。
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/features/settings/models/mcp_server_info.dart';
import 'package:agent/rust_bridge/api/mcp.dart' as api;
import 'package:agent/store/config_store.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/form/app_form_page.dart';
import 'package:agent/widgets/select/app_select.dart';
import 'package:agent/widgets/switch/app_switch.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 添加 MCP 服务器页。
class AddMcpServerPage extends HookWidget {
  final VoidCallback onBack;

  const AddMcpServerPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final store = ConfigStore.instance;

    final nameCtrl = useTextEditingController();
    final commandCtrl = useTextEditingController(text: 'npx');
    final argsCtrl = useTextEditingController();
    final urlCtrl = useTextEditingController(text: 'http://localhost:3000/mcp');
    final isStdio = useState(true);
    final disabled = useState(false);
    final saving = useState(false);
    final nameError = useState<String?>(null);
    final commandError = useState<String?>(null);
    final urlError = useState<String?>(null);

    Future<void> handleSave() async {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) {
        nameError.value = '请输入服务器名称';
        return;
      }
      if (isStdio.value && commandCtrl.text.trim().isEmpty) {
        commandError.value = '请输入命令';
        return;
      }
      if (!isStdio.value && urlCtrl.text.trim().isEmpty) {
        urlError.value = '请输入 URL';
        return;
      }

      final data = store.data.value;
      final existing = loadMcpServers(data);
      if (existing.any((s) => s.name == name)) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: AppText('服务器名称 "$name" 已存在')));
        }
        return;
      }

      saving.value = true;

      try {
        final server = isStdio.value
            ? McpServerInfo(
                name: name,
                command: commandCtrl.text.trim(),
                args: argsCtrl.text
                    .trim()
                    .split(RegExp(r'\s+'))
                    .where((a) => a.isNotEmpty)
                    .toList(),
                disabled: disabled.value,
              )
            : McpServerInfo(
                name: name,
                url: urlCtrl.text.trim(),
                disabled: disabled.value,
              );

        store.updateMcpServers((list) => list.add(server));

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: AppText('服务器添加成功')));
          // 通知 Rust 后端重新连接该服务器
          api.reloadMcpServer(configPath: store.configPath, serverName: name);
          onBack();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: AppText('保存失败: $e')));
        }
      } finally {
        saving.value = false;
      }
    }

    return AppFormPage(
      breadcrumbItems: [
        AppBreadcrumbItem('设置', onTap: () {}),
        AppBreadcrumbItem('MCP 服务器', onTap: onBack),
        AppBreadcrumbItem('添加服务器'),
      ],
      title: '添加 MCP 服务器',
      subtitle: 'Agent 启动时将自动启用配置的 MCP 服务器，并将其工具注入 LLM。',
      actions: FormActions(
        primary: [
          AppPrimaryButton(
            text: saving.value ? '保存中...' : '添加',
            onPressed: saving.value ? null : handleSave,
          ),
        ],
      ),
      children: [
        AppField(
          label: '名称',
          placeholder: '例如：filesystem',
          controller: nameCtrl,
          errorText: nameError.value,
          onChanged: (_) => nameError.value = null,
        ),
        AppSelect<String>(
          label: '传输方式',
          value: isStdio.value ? 'stdio' : 'http',
          options: const [
            AppSelectOption(value: 'stdio', label: 'STDIO'),
            AppSelectOption(value: 'http', label: 'HTTP'),
          ],
          onChanged: (v) {
            if (v != null) isStdio.value = v == 'stdio';
          },
        ),
        if (isStdio.value) ...[
          AppField(
            label: '命令',
            placeholder: '例如：npx',
            controller: commandCtrl,
            errorText: commandError.value,
            onChanged: (_) => commandError.value = null,
          ),
          AppField(
            label: '参数（空格分隔）',
            placeholder: '-y @modelcontextprotocol/server-filesystem /path',
            controller: argsCtrl,
          ),
        ] else
          AppField(
            label: 'URL',
            placeholder: 'http://localhost:3000/mcp',
            controller: urlCtrl,
            errorText: urlError.value,
            onChanged: (_) => urlError.value = null,
          ),
        AppSwitch(
          value: !disabled.value,
          onChanged: (v) => disabled.value = !v,
          size: SwitchSize.md,
          label: disabled.value ? '已禁用' : '添加后立即启用',
        ),
      ],
    );
  }
}
