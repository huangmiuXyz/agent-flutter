/// MCP 服务器编辑页 — 修改名称、命令或 URL 等。
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/settings/models/mcp_server_info.dart';

import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/store/config_store.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/dialog/app_dialog.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/form/app_form_page.dart';
import 'package:agent/widgets/select/app_select.dart';
import 'package:agent/widgets/switch/app_switch.dart';
import 'package:agent/widgets/text/app_text.dart';

/// MCP 服务器编辑/详情页。
class McpServerConfigPage extends HookWidget {
  final McpServerInfo server;
  final VoidCallback onBack;
  final VoidCallback? onManageDetail;

  const McpServerConfigPage({
    super.key,
    required this.server,
    required this.onBack,
    this.onManageDetail,
  });

  @override
  Widget build(BuildContext context) {
    final store = ConfigStore.instance;

    // 订阅 config 变化，跨窗口同步后立即更新标题等静态展示
    final configVersion = useExistingSignal(store.data).value;

    final nameCtrl = useTextEditingController(text: server.name);
    final commandCtrl = useTextEditingController(text: server.command);
    final argsCtrl = useTextEditingController(text: server.args.join(' '));
    final urlCtrl = useTextEditingController(text: server.url);
    final isStdio = useState(server.isStdio);
    final disabled = useState(server.disabled);
    final nameError = useState<String?>(null);
    final commandError = useState<String?>(null);
    final urlError = useState<String?>(null);

    // 从 ConfigStore 取最新的 server 数据（响应式）
    final latestServer = useMemoized(() {
      final servers = loadMcpServers(store.data.value);
      return servers.where((s) => s.name == server.name).firstOrNull ?? server;
    }, [configVersion, server]);

    // 跨窗口同步时更新表单字段
    useEffect(() {
      final servers = loadMcpServers(store.data.value);
      final updated = servers.where((s) => s.name == server.name).firstOrNull;
      if (updated == null) return null;
      nameCtrl.text = updated.name;
      commandCtrl.text = updated.command;
      argsCtrl.text = updated.args.join(' ');
      urlCtrl.text = updated.url;
      isStdio.value = updated.isStdio;
      disabled.value = updated.disabled;
      return null;
    }, [configVersion, server.name]);

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

      final updated = isStdio.value
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

      try {
        final oldName = server.name;
        final newName = updated.name;

        store.updateMcpServers((list) {
          final idx = list.indexWhere((s) => s.name == oldName);
          if (idx == -1) {
            list.add(updated);
          } else {
            list[idx] = updated;
          }
        });

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('配置保存成功')));
          // 通知 Rust 后端重新连接该服务器
          if (oldName != newName) {
            // 原名已从配置中移除，断开旧连接
            api.reloadMcpServer(
              configPath: store.configPath,
              serverName: oldName,
            );
          }
          api.reloadMcpServer(
            configPath: store.configPath,
            serverName: newName,
          );
          onBack();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
        }
      }
    }

    Future<void> handleDelete() async {
      final confirmed = await AppDialog.show(
        context: context,
        title: '确认删除',
        okText: '删除',
        child: AppText('确定要删除 MCP 服务器 "${server.name}" 吗？\n\n此操作不可撤销。'),
      );
      if (confirmed != true) return;

      try {
        store.updateMcpServers((list) {
          list.removeWhere((s) => s.name == server.name);
        });

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已删除')));
          // 通知 Rust 后端断开该服务器
          api.reloadMcpServer(
            configPath: store.configPath,
            serverName: server.name,
          );
          onBack();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
        }
      }
    }

    return AppFormPage(
      breadcrumbItems: [
        AppBreadcrumbItem('设置', onTap: () {}),
        AppBreadcrumbItem('MCP 服务器', onTap: onBack),
        AppBreadcrumbItem(latestServer.name),
      ],
      title: latestServer.name,
      subtitle: '编辑 MCP 服务器配置',
      actions: FormActions(
        primary: [
          AppPrimaryButton(text: '保存', onPressed: handleSave),
        ],
        secondary: [
          AppSecondaryButton(
            text: '管理详情',
            onPressed: onManageDetail,
          ),
          AppSecondaryButton(
            text: '删除',
            onPressed: handleDelete,
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
          label: disabled.value ? '已禁用' : '已启用',
        ),
      ],
    );
  }
}
