/// 高级设置页面 — 工作目录配置
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:file_picker/file_picker.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/store/config_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 高级设置页面。
///
/// 当前只包含一个配置项：工作目录。
class AdvancedSettingsPage extends HookWidget {
  /// 面包屑「设置」点击回调。为 null 时不显示链接样式。
  final VoidCallback? onBack;

  const AdvancedSettingsPage({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final ctrl = useTextEditingController();

    // 订阅 config 变化，跨窗口同步后重新加载
    final configVersion = useExistingSignal(ConfigStore.instance.data).value;

    // 从 ConfigStore 加载当前值
    useEffect(() {
      final wd = ConfigStore.instance.workDir.value;
      ctrl.text = wd;
      return null;
    }, [configVersion]);

    Future<void> handlePickDir() async {
      try {
        final result = await FilePicker.getDirectoryPath(
          dialogTitle: '选择工作目录',
        );
        if (result != null && context.mounted) {
          // Windows 返回的路径用反斜杠，统一为正斜杠
          ctrl.text = result.replaceAll('\\', '/');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('选择目录失败: $e')),
          );
        }
      }
    }

    Future<void> handleSave() async {
      final path = ctrl.text.trim();
      try {
        ConfigStore.instance.updateWorkDir(path);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('工作目录已保存，新建终端时生效')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存失败: $e')),
          );
        }
      }
    }

    void handleReset() {
      ctrl.text = '';
      ConfigStore.instance.updateWorkDir('');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('工作目录已重置')),
      );
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
                AppBreadcrumbItem('设置', onTap: onBack),
                AppBreadcrumbItem('高级'),
              ],
            ),
            SizedBox(height: custom.spacing.lg),

            // ── Title ──
            AppText('高级设置', variant: AppTextVariant.h2),
            SizedBox(height: custom.spacing.xs),
            AppText(
              '配置工作目录后，新建终端（Terminal）会自动进入该目录。'
              '修改即时生效，不影响已运行的终端。',
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
            ),
            SizedBox(height: custom.spacing.lg + 4),

            // ── 工作目录 ──
            AppText(
              '工作目录',
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
            ),
            SizedBox(height: custom.spacing.xs),
            Row(
              children: [
                Expanded(
                  child: AppField(
                    controller: ctrl,
                    placeholder: _defaultHint(),
                    icon: 'folderOpen',
                  ),
                ),
                SizedBox(width: custom.spacing.sm),
                AppSecondaryButton(
                  text: '选择…',
                  onPressed: handlePickDir,
                ),
              ],
            ),
            SizedBox(height: custom.spacing.md),

            // ── Actions ──
            Row(
              children: [
                AppPrimaryButton(text: '保存', onPressed: handleSave),
                SizedBox(width: custom.spacing.sm),
                AppSecondaryButton(text: '重置', onPressed: handleReset),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _defaultHint() {
    if (Platform.isMacOS) return '例如: /Users/username/projects/my-app';
    if (Platform.isWindows) return '例如: C:\\Users\\username\\projects';
    return '例如: /home/username/projects';
  }
}
