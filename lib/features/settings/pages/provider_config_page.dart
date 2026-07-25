/// Provider config page — API Key, Endpoint, default model settings.
///
/// Persists to config.json via [ConfigFileStore]:
///   language_models.openai_compatible.{id}.api_url
///   language_models.{protocol}.{id}.api_key
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/features/settings/models/provider_info.dart';
import 'package:agent/features/settings/pages/model_list_page.dart';
import 'package:agent/services/config_service.dart';
import 'package:agent/services/llm/llm_providers.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/dialog/app_dialog.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Full-screen config form for a single provider.
///
/// Manages navigation between the config form and model management page.
class ProviderConfigPage extends HookConsumerWidget {
  final ProviderInfo provider;

  /// Called when the user wants to go back to the provider list.
  final VoidCallback onBack;

  const ProviderConfigPage({
    super.key,
    required this.provider,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
class _ConfigForm extends HookConsumerWidget {
  final ProviderInfo provider;
  final VoidCallback onBack;
  final VoidCallback onManageModels;

  const _ConfigForm({
    required this.provider,
    required this.onBack,
    required this.onManageModels,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiKeyCtrl = useTextEditingController();
    final endpointCtrl = useTextEditingController(text: provider.baseUrl ?? '');
    // Detect protocol from provider type
    final protocol = _protocolFor(provider.name);

    // ── Load existing config on mount ──
    useEffect(() {
      try {
        final store = ref.read(configFileStoreProvider);
        final keyPrefix = 'language_models.$protocol.${provider.name}';
        final rawUrl = store.readPath('$keyPrefix.api_url');
        if (rawUrl != null && rawUrl != 'null') {
          final url = jsonDecode(rawUrl) as String;
          if (url.isNotEmpty) {
            endpointCtrl.text = url;
          }
        }
        final rawKey = store.readPath('$keyPrefix.api_key');
        if (rawKey != null && rawKey != 'null') {
          final key = jsonDecode(rawKey) as String;
          if (key.isNotEmpty) {
            apiKeyCtrl.text = key;
          }
        }
      } catch (_) {}
      return null;
    }, [provider.name]);

    final custom = CustomTheme.of(context);

    // ── Save handler ──
    Future<void> handleSave() async {
      try {
        final store = ref.read(configFileStoreProvider);
        final keyPrefix = 'language_models.$protocol.${provider.name}';

        store.writePath('$keyPrefix.api_url', endpointCtrl.text);
        if (apiKeyCtrl.text.isNotEmpty) {
          store.writePath('$keyPrefix.api_key', apiKeyCtrl.text);
        }

        ref.invalidate(providersListProvider);
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
                AppBreadcrumbItem(provider.label),
              ],
            ),
            SizedBox(height: custom.spacing.lg),

            // ---- Title ----
            AppText(provider.label, variant: AppTextVariant.h2),
            if (provider.baseUrl != null) ...[
              SizedBox(height: custom.spacing.xs),
              AppText(
                provider.baseUrl!,
                variant: AppTextVariant.caption,
                color: custom.colors.textSecondary,
              ),
            ],
            SizedBox(height: custom.spacing.lg + 4),

            // ---- API Key ----
            AppField(
              label: 'API Key',
              placeholder: '输入 ${provider.label} 的 API Key',
              obscureText: true,
              controller: apiKeyCtrl,
            ),
            SizedBox(height: custom.spacing.md),

            // ---- Endpoint ----
            AppField(
              label: 'API Endpoint（可选）',
              placeholder: provider.baseUrl ?? 'https://api.example.com/v1',
              controller: endpointCtrl,
            ),
            SizedBox(height: custom.spacing.lg + 4),

            // ---- Actions ----
            Row(
              children: [
                AppPrimaryButton(text: '保存', onPressed: handleSave),
                const Spacer(),
                if (provider.configured)
                  AppSecondaryButton(text: '管理模型', onPressed: onManageModels),
                if (provider.configured) SizedBox(width: custom.spacing.sm),
                if (provider.configured)
                  AppSecondaryButton(
                    text: '删除配置',
                    onPressed: () => _handleDelete(context, ref),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.show(
      context: context,
      title: '确认删除',
      okText: '删除',
      child: AppText('确定要删除 ${provider.label} 的配置吗？\n\n此操作不可撤销。'),
    );
    if (confirmed != true) return;

    try {
      final store = ref.read(configFileStoreProvider);
      final data = store.readAll();

      // Remove the provider's config section if it exists
      final protocol = _protocolFor(provider.name);
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

      store.writeAll(data);
      ref.invalidate(providersListProvider);
      debugPrint('Deleted provider config: $protocol.${provider.name}');

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

/// Map provider name to the protocol used in config.json.
///
/// - Anthropic → "anthropic"
/// - Everything else → "openai_compatible"
String _protocolFor(String name) {
  if (name == 'Anthropic') return 'anthropic';
  return 'openai_compatible';
}
