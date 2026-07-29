/// 添加 MCP 服务器页。
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/features/settings/models/mcp_server_info.dart';
import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/store/config_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/select/app_select.dart';
import 'package:agent/widgets/switch/app_switch.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 添加 MCP 服务器页。
class AddMcpServerPage extends HookWidget {
  final VoidCallback onBack;

  const AddMcpServerPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final store = ConfigStore.instance;

    final nameCtrl = useTextEditingController();
    final commandCtrl = useTextEditingController(text: 'npx');
    final argsCtrl = useTextEditingController();
    final urlCtrl = useTextEditingController(text: 'http://localhost:3000/mcp');
    final isStdio = useState(true);
    final disabled = useState(false);
    final saving = useState(false);
    final errorMsg = useState<String?>(null);

    Future<void> handleSave() async {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) {
        errorMsg.value = '请输入服务器名称';
        return;
      }
      if (isStdio.value && commandCtrl.text.trim().isEmpty) {
        errorMsg.value = '请输入命令';
        return;
      }
      if (!isStdio.value && urlCtrl.text.trim().isEmpty) {
        errorMsg.value = '请输入 URL';
        return;
      }

      final data = store.data.value;
      final existing = loadMcpServers(data);
      if (existing.any((s) => s.name == name)) {
        errorMsg.value = '服务器名称 "$name" 已存在';
        return;
      }

      saving.value = true;
      errorMsg.value = null;

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
          ).showSnackBar(const SnackBar(content: Text('服务器添加成功')));
          // 通知 Rust 后端重新连接该服务器
          api.reloadMcpServer(
            configPath: store.configPath,
            serverName: name,
          );
          onBack();
        }
      } catch (e) {
        errorMsg.value = '保存失败: $e';
      } finally {
        saving.value = false;
      }
    }

    return ContentFrame(
      child: SizedBox(
        width: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppBreadcrumb(
              items: [
                AppBreadcrumbItem('设置', onTap: () {}),
                AppBreadcrumbItem('MCP 服务器', onTap: onBack),
                AppBreadcrumbItem('添加服务器'),
              ],
            ),
            SizedBox(height: custom.spacing.lg),

            AppText('添加 MCP 服务器', variant: AppTextVariant.h2),
            SizedBox(height: custom.spacing.xs),
            AppText(
              'Agent 启动时将自动启用配置的 MCP 服务器，并将其工具注入 LLM。',
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
            ),
            SizedBox(height: custom.spacing.lg + 4),

            AppField(
              label: '名称',
              placeholder: '例如：filesystem',
              controller: nameCtrl,
              onChanged: (_) {
                if (errorMsg.value != null) errorMsg.value = null;
              },
            ),
            SizedBox(height: custom.spacing.md),

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
            SizedBox(height: custom.spacing.md),

            if (isStdio.value) ...[
              AppField(
                label: '命令',
                placeholder: '例如：npx',
                controller: commandCtrl,
              ),
              SizedBox(height: custom.spacing.md),
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
              ),

            SizedBox(height: custom.spacing.md),

            Row(
              children: [
                AppSwitch(
                  value: !disabled.value,
                  onChanged: (v) => disabled.value = !v,
                  size: SwitchSize.md,
                ),
                SizedBox(width: custom.spacing.sm),
                AppText(disabled.value ? '已禁用' : '添加后立即启用'),
              ],
            ),

            SizedBox(height: custom.spacing.lg + 4),

            if (errorMsg.value != null)
              Padding(
                padding: EdgeInsets.only(top: custom.spacing.sm),
                child: AppText(
                  errorMsg.value!,
                  variant: AppTextVariant.caption,
                  color: custom.colors.danger,
                ),
              ),

            SizedBox(height: custom.spacing.lg + 4),

            Row(
              children: [
                AppPrimaryButton(
                  text: saving.value ? '保存中...' : '添加',
                  onPressed: saving.value ? null : handleSave,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
