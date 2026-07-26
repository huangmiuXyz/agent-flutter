/// Add custom provider page — form to create a new OpenAI-compatible provider.
///
/// Persists to config.json via [ConfigStore]:
///   language_models.openai_compatible.{name}.api_url
///   language_models.openai_compatible.{name}.api_key
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/store/config_store.dart';
import 'package:agent/store/llm_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Full-screen form for adding a custom OpenAI-compatible provider.
class AddProviderPage extends HookWidget {
  /// Called when the user wants to go back to the provider list.
  final VoidCallback onBack;

  const AddProviderPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final nameCtrl = useTextEditingController();
    final apiKeyCtrl = useTextEditingController();
    final endpointCtrl = useTextEditingController(
      text: 'https://api.openai.com/v1',
    );
    final saving = useState(false);
    final errorMsg = useState<String?>(null);

    Future<void> handleSave() async {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) {
        errorMsg.value = '请输入提供商名称';
        return;
      }
      final providerId = name.replaceAll(RegExp(r'\s+'), '_').toLowerCase();
      if (providerId.isEmpty) {
        errorMsg.value = '提供商名称不能为空';
        return;
      }

      saving.value = true;
      errorMsg.value = null;

      try {
        final url = endpointCtrl.text.trim().isNotEmpty
            ? endpointCtrl.text.trim()
            : 'https://api.openai.com/v1';

        ConfigStore.instance.mutate((m) {
          final cfg =
              m['language_models']['openai_compatible'].putIfAbsent(
                    providerId,
                    () => <String, dynamic>{},
                  )
                  as Map<String, dynamic>;
          cfg['api_url'] = url;
          if (apiKeyCtrl.text.trim().isNotEmpty) {
            cfg['api_key'] = apiKeyCtrl.text.trim();
          }
        });

        LlmStore.instance.loadProviders(ConfigStore.instance.configPath);

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('提供商添加成功')));
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
                AppBreadcrumbItem('提供商', onTap: onBack),
                AppBreadcrumbItem('添加提供商'),
              ],
            ),
            SizedBox(height: custom.spacing.lg),

            AppText('添加自定义提供商', variant: AppTextVariant.h2),
            SizedBox(height: custom.spacing.xs),
            AppText(
              '添加一个兼容 OpenAI API 的自定义模型提供商',
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
            ),
            SizedBox(height: custom.spacing.lg + 4),

            AppField(
              label: '提供商名称',
              placeholder: '例如：我的模型服务',
              controller: nameCtrl,
              onChanged: (_) {
                if (errorMsg.value != null) {
                  errorMsg.value = null;
                }
              },
            ),
            SizedBox(height: custom.spacing.md),

            AppField(
              label: 'API Key',
              placeholder: '输入 API Key',
              obscureText: false,
              controller: apiKeyCtrl,
            ),
            SizedBox(height: custom.spacing.md),

            AppField(
              label: 'API Endpoint',
              placeholder: 'https://api.openai.com/v1',
              controller: endpointCtrl,
            ),
            SizedBox(height: custom.spacing.md),

            if (errorMsg.value != null)
              Padding(
                padding: EdgeInsets.only(bottom: custom.spacing.sm),
                child: AppText(
                  errorMsg.value!,
                  variant: AppTextVariant.caption,
                  color: custom.colors.danger,
                ),
              ),

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
