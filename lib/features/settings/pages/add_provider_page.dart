/// Add custom provider page — form to create a new provider.
///
/// Persists to config.json via [ConfigStore]:
///   language_models.{protocol}.{name}.api_url
///   language_models.{protocol}.{name}.api_key
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/features/settings/models/provider_info.dart';
import 'package:agent/store/config_store.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/form/app_form_page.dart';
import 'package:agent/widgets/select/app_select.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Full-screen form for adding a custom provider.
class AddProviderPage extends HookWidget {
  /// Called when the user wants to go back to the provider list.
  final VoidCallback onBack;

  /// Called after the provider is saved successfully, with the new provider info.
  final ValueChanged<ProviderInfo>? onSaved;

  const AddProviderPage({super.key, required this.onBack, this.onSaved});

  @override
  Widget build(BuildContext context) {
    final nameCtrl = useTextEditingController();
    final apiKeyCtrl = useTextEditingController();
    final endpointCtrl = useTextEditingController(
      text: 'https://api.openai.com/v1',
    );
    final protocol = useState<String>('openai_compatible');
    final saving = useState(false);
    final nameError = useState<String?>(null);

    Future<void> handleSave() async {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) {
        nameError.value = '请输入提供商名称';
        return;
      }
      final providerId = name.replaceAll(RegExp(r'\s+'), '_').toLowerCase();
      if (providerId.isEmpty) {
        nameError.value = '提供商名称不能为空';
        return;
      }

      saving.value = true;
      nameError.value = null;

      try {
        final url = endpointCtrl.text.trim().isNotEmpty
            ? endpointCtrl.text.trim()
            : 'https://api.openai.com/v1';

        ConfigStore.instance.mutate((m) {
          final languageModels =
              m.putIfAbsent('language_models', () => <String, dynamic>{})
                  as Map<String, dynamic>;
          final protocolConfig =
              languageModels.putIfAbsent(
                    protocol.value,
                    () => <String, dynamic>{},
                  )
                  as Map<String, dynamic>;
          final cfg =
              protocolConfig.putIfAbsent(providerId, () => <String, dynamic>{})
                  as Map<String, dynamic>;
          cfg['api_url'] = url;
          if (apiKeyCtrl.text.trim().isNotEmpty) {
            cfg['api_key'] = apiKeyCtrl.text.trim();
          }
        });

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: AppText('提供商添加成功')));
          onSaved?.call(
            ProviderInfo(
              name: providerId,
              displayName: name,
              baseUrl: url,
              configured: true,
            ),
          );
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
        AppBreadcrumbItem('提供商', onTap: onBack),
        AppBreadcrumbItem('添加提供商'),
      ],
      title: '添加自定义提供商',
      subtitle: '添加一个自定义模型提供商',
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
          label: '提供商名称',
          placeholder: '例如：我的模型服务',
          controller: nameCtrl,
          errorText: nameError.value,
          onChanged: (_) => nameError.value = null,
        ),
        AppSelect<String>(
          label: '协议类型',
          placeholder: '选择 API 协议',
          value: protocol.value,
          options: protocolOptions,
          onChanged: (v) => protocol.value = v ?? 'openai_compatible',
        ),
        AppField(
          label: 'API Key',
          placeholder: '输入 API Key',
          obscureText: false,
          controller: apiKeyCtrl,
        ),
        AppField(
          label: 'API Endpoint',
          placeholder: 'https://api.openai.com/v1',
          controller: endpointCtrl,
        ),
      ],
    );
  }
}
