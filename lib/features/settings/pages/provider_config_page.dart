/// Provider config page — API Key, Endpoint, default model settings.
///
/// Persists to config.json via [ConfigFileStore]:
///   language_models.openai_compatible.{id}.api_url
///   language_models.{protocol}.{id}.api_key
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/settings/models/provider_info.dart';
import 'package:agent/features/settings/pages/model_list_page.dart';
import 'package:agent/store/config_store.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/dialog/app_dialog.dart';
import 'package:agent/widgets/form/app_form_page.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Full-screen config form for a single provider.
///
/// Manages navigation between the config form and model management page.
class ProviderConfigPage extends HookWidget {
  final ProviderInfo provider;

  /// Called when the user wants to go back to the provider list.
  final VoidCallback onBack;

  const ProviderConfigPage({
    super.key,
    required this.provider,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final showModels = useState(false);

    return showModels.value
        ? ModelListPage(
            provider: provider,
            onBack: () => showModels.value = false,
          )
        : _ConfigForm(
            provider: provider,
            onBack: onBack,
            onManageModels: () => showModels.value = true,
          );
  }
}

/// The config form body (extracted to avoid conditional hooks).
class _ConfigForm extends HookWidget {
  final ProviderInfo provider;
  final VoidCallback onBack;
  final VoidCallback onManageModels;

  const _ConfigForm({
    required this.provider,
    required this.onBack,
    required this.onManageModels,
  });

  @override
  Widget build(BuildContext context) {
    final apiKeyCtrl = useTextEditingController();
    final endpointCtrl = useTextEditingController(text: provider.baseUrl ?? '');
    // Detect protocol from provider type
    final protocol = protocolForProvider(provider.name);

    // 订阅 config 变化，跨窗口同步后重新加载表单
    final configVersion = useExistingSignal(ConfigStore.instance.data).value;

    // ── Load existing config on mount or config change ──
    useEffect(() {
      try {
        final section =
            (ConfigStore.instance.data.value['language_models']
                    as Map<String, dynamic>?)?[protocol]?[provider.name]
                as Map<String, dynamic>?;
        if (section != null) {
          final url = section['api_url'] as String?;
          if (url != null && url.isNotEmpty) {
            endpointCtrl.text = url;
          }
          final key = section['api_key'] as String?;
          if (key != null && key.isNotEmpty) {
            apiKeyCtrl.text = key;
          }
        }
      } catch (_) {}
      return null;
    }, [configVersion, provider.name]);

    // ── Save handler ──
    Future<void> handleSave() async {
      try {
        ConfigStore.instance.mutate((m) {
          // Ensure the full path exists, creating missing sections as needed
          final languageModels =
              m.putIfAbsent('language_models', () => <String, dynamic>{})
                  as Map<String, dynamic>;
          final protocolConfig =
              languageModels.putIfAbsent(protocol, () => <String, dynamic>{})
                  as Map<String, dynamic>;
          final cfg =
              protocolConfig.putIfAbsent(
                    provider.name,
                    () => <String, dynamic>{},
                  )
                  as Map<String, dynamic>;
          cfg['api_url'] = endpointCtrl.text;
          if (apiKeyCtrl.text.isNotEmpty) {
            cfg['api_key'] = apiKeyCtrl.text;
          }
        });

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('配置保存成功')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
        }
      }
    }

    return AppFormPage(
      breadcrumbItems: [
        AppBreadcrumbItem('设置', onTap: () {}),
        AppBreadcrumbItem('提供商', onTap: onBack),
        AppBreadcrumbItem(provider.label),
      ],
      title: provider.label,
      subtitle: provider.baseUrl,
      actions: FormActions(
        primary: [
          AppPrimaryButton(text: '保存', onPressed: handleSave),
        ],
        secondary: [
          if (provider.configured)
            AppSecondaryButton(text: '管理模型', onPressed: onManageModels),
          if (provider.configured)
            AppSecondaryButton(
              text: '删除配置',
              onPressed: () => _handleDelete(context),
            ),
        ],
      ),
      children: [
        AppField(
          label: 'API Key',
          placeholder: '输入 ${provider.label} 的 API Key',
          obscureText: false,
          controller: apiKeyCtrl,
        ),
        AppField(
          label: 'API Endpoint（可选）',
          placeholder: provider.baseUrl ?? 'https://api.example.com/v1',
          controller: endpointCtrl,
        ),
      ],
    );
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await AppDialog.show(
      context: context,
      title: '确认删除',
      okText: '删除',
      child: AppText('确定要删除 ${provider.label} 的配置吗？\n\n此操作不可撤销。'),
    );
    if (confirmed != true) return;

    try {
      ConfigStore.instance.mutate((data) {
        // Remove the provider's config section if it exists
        final protocol = protocolForProvider(provider.name);
        final models = data['language_models'] as Map<String, dynamic>?;
        if (models != null) {
          final protocolConfig = models[protocol] as Map<String, dynamic>?;
          if (protocolConfig != null) {
            protocolConfig.remove(provider.name);
            if (protocolConfig.isEmpty) {
              models.remove(protocol);
            }
          }
          if (models.isEmpty) {
            data.remove('language_models');
          }
        }
      });

      debugPrint(
        'Deleted provider config: ${protocolForProvider(provider.name)}.${provider.name}',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('配置已删除')));
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
}
