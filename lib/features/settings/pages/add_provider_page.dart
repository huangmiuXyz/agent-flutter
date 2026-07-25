/// Add custom provider page — form to create a new OpenAI-compatible provider.
///
/// Persists to config.json via [ConfigFileStore]:
///   language_models.openai_compatible.{name}.api_url
///   language_models.openai_compatible.{name}.api_key
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/services/config_service.dart';
import 'package:agent/services/llm/llm_providers.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Full-screen form for adding a custom OpenAI-compatible provider.
class AddProviderPage extends HookConsumerWidget {
  /// Called when the user wants to go back to the provider list.
  final VoidCallback onBack;

  const AddProviderPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = CustomTheme.of(context);
    final nameCtrl = useTextEditingController();
    final apiKeyCtrl = useTextEditingController();
    final endpointCtrl = useTextEditingController(text: 'https://api.openai.com/v1');
    final saving = useState(false);
    final errorMsg = useState<String?>(null);

    Future<void> handleSave() async {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) {
        errorMsg.value = '请输入提供商名称';
        return;
      }
      // Check if the provider ID is valid (no special chars, not empty)
      final providerId = name.replaceAll(RegExp(r'\s+'), '_').toLowerCase();
      if (providerId.isEmpty) {
        errorMsg.value = '提供商名称不能为空';
        return;
      }

      saving.value = true;
      errorMsg.value = null;

      try {
        final store = ref.read(configFileStoreProvider);
        final keyPrefix = 'language_models.openai_compatible.$providerId';

        store.writePath(
          '$keyPrefix.api_url',
          endpointCtrl.text.trim().isNotEmpty
              ? endpointCtrl.text.trim()
              : 'https://api.openai.com/v1',
        );
        if (apiKeyCtrl.text.trim().isNotEmpty) {
          store.writePath(
            '$keyPrefix.api_key',
            apiKeyCtrl.text.trim(),
          );
        }

        ref.invalidate(providersListProvider);

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
            // ---- Breadcrumb ----
            AppBreadcrumb(
              items: [
                AppBreadcrumbItem('设置', onTap: () {}),
                AppBreadcrumbItem('提供商', onTap: onBack),
                AppBreadcrumbItem('添加提供商'),
              ],
            ),
            SizedBox(height: custom.spacing.lg),

            // ---- Title ----
            AppText('添加自定义提供商', variant: AppTextVariant.h2),
            SizedBox(height: custom.spacing.xs),
            AppText(
              '添加一个兼容 OpenAI API 的自定义模型提供商',
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
            ),
            SizedBox(height: custom.spacing.lg + 4),

            // ---- Provider Name ----
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

            // ---- API Key ----
            AppField(
              label: 'API Key',
              placeholder: '输入 API Key',
              obscureText: true,
              controller: apiKeyCtrl,
            ),
            SizedBox(height: custom.spacing.md),

            // ---- Endpoint ----
            AppField(
              label: 'API Endpoint',
              placeholder: 'https://api.openai.com/v1',
              controller: endpointCtrl,
            ),
            SizedBox(height: custom.spacing.md),

            // ---- Error message ----
            if (errorMsg.value != null)
              Padding(
                padding: EdgeInsets.only(bottom: custom.spacing.sm),
                child: AppText(
                  errorMsg.value!,
                  variant: AppTextVariant.caption,
                  color: custom.colors.danger,
                ),
              ),

            // ---- Actions ----
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
