/// 添加 MCP 服务器页 — 填写名称、传输方式等信息。
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/features/settings/models/mcp_server_info.dart';
import 'package:agent/services/config_service.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/select/app_select.dart';
import 'package:agent/widgets/switch/app_switch.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 添加 MCP 服务器页。
class AddMcpServerPage extends HookConsumerWidget {
  final VoidCallback onBack;

  const AddMcpServerPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = CustomTheme.of(context);
    final store = ref.watch(configFileStoreProvider);

    final nameCtrl = useTextEditingController();
    final commandCtrl = useTextEditingController(text: 'npx');
    final argsCtrl = useTextEditingController();
    final urlCtrl = useTextEditingController(text: 'http://localhost:3000/mcp');
    final transportType = useState('stdio');
    final enabled = useState(true);
    final saving = useState(false);
    final errorMsg = useState<String?>(null);

    Future<void> handleSave() async {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) {
        errorMsg.value = '请输入服务器名称';
        return;
      }
      // 检查名称是否已存在
      final data = store.readAll();
      final existing = loadMcpServers(data);
      if (existing.any((s) => s.name == name)) {
        errorMsg.value = '服务器名称 "$name" 已存在';
        return;
      }

      saving.value = true;
      errorMsg.value = null;

      try {
        final server = McpServerInfo(
          name: name,
          transportType: transportType.value,
          command:
              transportType.value == 'stdio' ? commandCtrl.text.trim() : '',
          args: transportType.value == 'stdio'
              ? argsCtrl.text
                  .trim()
                  .split(RegExp(r'\s+'))
                  .where((a) => a.isNotEmpty)
                  .toList()
              : [],
          url: transportType.value == 'http' ? urlCtrl.text.trim() : '',
          enabled: enabled.value,
        );

        saveMcpServers(data, [...existing, server]);
        store.writeAll(data);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('服务器添加成功')),
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
            // ── Breadcrumb ──
            AppBreadcrumb(
              items: [
                AppBreadcrumbItem('设置', onTap: () {}),
                AppBreadcrumbItem('MCP 服务器', onTap: onBack),
                AppBreadcrumbItem('添加服务器'),
              ],
            ),
            SizedBox(height: custom.spacing.lg),

            // ── Title ──
            AppText('添加 MCP 服务器', variant: AppTextVariant.h2),
            SizedBox(height: custom.spacing.xs),
            AppText(
              'Agent 启动时将自动连接已启用的 MCP 服务器，并将其工具注入 LLM。',
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
            ),
            SizedBox(height: custom.spacing.lg + 4),

            // ── 名称 ──
            AppField(
              label: '名称',
              placeholder: '例如：filesystem',
              controller: nameCtrl,
              onChanged: (_) {
                if (errorMsg.value != null) errorMsg.value = null;
              },
            ),
            SizedBox(height: custom.spacing.md),

            // ── 传输方式 ──
            AppSelect<String>(
              label: '传输方式',
              value: transportType.value,
              options: const [
                AppSelectOption(value: 'stdio', label: 'STDIO'),
                AppSelectOption(value: 'http', label: 'HTTP'),
              ],
              onChanged: (v) {
                if (v != null) transportType.value = v;
              },
            ),
            SizedBox(height: custom.spacing.md),

            // ── STDIO 参数 ──
            if (transportType.value == 'stdio') ...[
              AppField(
                label: '命令',
                placeholder: '例如：npx',
                controller: commandCtrl,
              ),
              SizedBox(height: custom.spacing.md),
              AppField(
                label: '参数（空格分隔）',
                placeholder:
                    '-y @modelcontextprotocol/server-filesystem /path',
                controller: argsCtrl,
              ),
            ],

            // ── HTTP 参数 ──
            if (transportType.value == 'http')
              AppField(
                label: 'URL',
                placeholder: 'http://localhost:3000/mcp',
                controller: urlCtrl,
              ),

            SizedBox(height: custom.spacing.md),

            // ── 启用开关 ──
            Row(
              children: [
                AppSwitch(
                  value: enabled.value,
                  onChanged: (v) => enabled.value = v,
                  size: SwitchSize.md,
                ),
                SizedBox(width: custom.spacing.sm),
                AppText('添加后立即启用'),
              ],
            ),

            // ── 错误信息 ──
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

            // ── 操作按钮 ──
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
