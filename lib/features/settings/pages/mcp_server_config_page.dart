/// MCP 服务器编辑页 — 修改名称、传输方式、启用状态等。
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/features/settings/models/mcp_server_info.dart';

import 'package:agent/services/config_service.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/dialog/app_dialog.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/select/app_select.dart';
import 'package:agent/widgets/switch/app_switch.dart';
import 'package:agent/widgets/text/app_text.dart';

/// MCP 服务器编辑/详情页。
class McpServerConfigPage extends HookConsumerWidget {
  final McpServerInfo server;
  final VoidCallback onBack;

  const McpServerConfigPage({
    super.key,
    required this.server,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = CustomTheme.of(context);
    final store = ref.watch(configFileStoreProvider);

    // ── Form state ──
    final nameCtrl = useTextEditingController(text: server.name);
    final commandCtrl = useTextEditingController(text: server.command);
    final argsCtrl = useTextEditingController(text: server.args.join(' '));
    final urlCtrl = useTextEditingController(text: server.url);
    final transportType = useState(server.transportType);
    final enabled = useState(server.enabled);
    final errorMsg = useState<String?>(null);

    Future<void> handleSave() async {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) {
        errorMsg.value = '请输入服务器名称';
        return;
      }

      // 构建更新后的配置
      final updated = McpServerInfo(
        name: name,
        transportType: transportType.value,
        command: transportType.value == 'stdio' ? commandCtrl.text.trim() : '',
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

      try {
        // 读取现有列表，替换或追加
        final data = store.readAll();
        final existing = loadMcpServers(data);
        final idx = existing.indexWhere((s) => s.name == server.name);
        final List<McpServerInfo> updatedList;
        if (idx == -1) {
          updatedList = [...existing, updated];
        } else {
          updatedList = [...existing];
          updatedList[idx] = updated;
        }
        saveMcpServers(data, updatedList);
        store.writeAll(data);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('配置保存成功')),
          );
          onBack();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存失败: $e')),
          );
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
        final delData = store.readAll();
        final existing = loadMcpServers(delData);
        existing.removeWhere((s) => s.name == server.name);
        saveMcpServers(delData, existing);
        store.writeAll(delData);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已删除')),
          );
          onBack();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
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
                AppBreadcrumbItem(server.name),
              ],
            ),
            SizedBox(height: custom.spacing.lg),

            // ── Title ──
            AppText(server.name, variant: AppTextVariant.h2),
            SizedBox(height: custom.spacing.xs),
            AppText(
              '编辑 MCP 服务器配置',
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
            ),
            SizedBox(height: custom.spacing.lg + 4),

            // ── 名称 ──
            AppField(
              label: '名称',
              placeholder: '例如：filesystem',
              controller: nameCtrl,
              onChanged: (_) => errorMsg.value = null,
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
                placeholder: '-y @modelcontextprotocol/server-filesystem /path',
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
                AppText('启用'),
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
                AppPrimaryButton(text: '保存', onPressed: handleSave),
                const Spacer(),
                AppSecondaryButton(
                  text: '删除',
                  size: ButtonSize.md,
                  onPressed: handleDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
