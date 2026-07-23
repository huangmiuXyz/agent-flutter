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
import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/services/config_service.dart';
import 'package:agent/services/llm/llm_providers.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/select/app_select.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Full-screen config form for a single provider.
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
    final apiKeyCtrl = useTextEditingController();
    final endpointCtrl = useTextEditingController(text: provider.baseUrl ?? '');
    final selectedModel = useState<String?>(null);

    // Detect protocol from provider type
    final protocol = _protocolFor(provider.name);

    // ── Load existing config on mount ──
    // Load existing config on mount
    useEffect(() {
      Future<void> load() async {
        try {
          final cfgPath = ref.read(configPathProvider);
          final keyPrefix = 'language_models.$protocol.${provider.name}';
          final rawUrl = await api.getConfig(
            configPath: cfgPath,
            key: '$keyPrefix.api_url',
          );
          if (rawUrl.isNotEmpty && rawUrl != 'null') {
            final url = jsonDecode(rawUrl) as String;
            if (url.isNotEmpty) {
              endpointCtrl.text = url;
            }
          }
          final rawKey = await api.getConfig(
            configPath: cfgPath,
            key: '$keyPrefix.api_key',
          );
          if (rawKey.isNotEmpty && rawKey != 'null') {
            final key = jsonDecode(rawKey) as String;
            if (key.isNotEmpty) {
              apiKeyCtrl.text = key;
            }
          }
        } catch (_) {}
      }

      load();
      return null;
    }, [provider.name]);

    final custom = CustomTheme.of(context);
    // ── Save handler ──
    // Save handler
    Future<void> handleSave() async {
      try {
        final cfgPath = ref.read(configPathProvider);
        final keyPrefix = 'language_models.$protocol.${provider.name}';

        await api.setConfig(
          configPath: cfgPath,
          key: '$keyPrefix.api_url',
          value: endpointCtrl.text,
        );
        if (apiKeyCtrl.text.isNotEmpty) {
          await api.setConfig(
            configPath: cfgPath,
            key: '$keyPrefix.api_key',
            value: apiKeyCtrl.text,
          );
        }
        ref.invalidate(providersListProvider);
        debugPrint('Saved provider config: $keyPrefix');
      } catch (e) {
        debugPrint('Save failed: $e');
      }
    }

    // Mock model list — real data comes from [modelsList] provider
    final models = [AppSelectOption(value: 'default', label: '默认模型')];

    return ContentFrame(
      child: SizedBox(
        width: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Breadcrumb ----
            AppBreadcrumb(
              items: [
                AppBreadcrumbItem('Settings', onTap: () {}),
                AppBreadcrumbItem('Models', onTap: onBack),
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
            SizedBox(height: custom.spacing.md),

            // ---- Default Model ----
            AppSelect<String>(
              label: '默认模型',
              placeholder: '选择默认模型',
              value: selectedModel.value,
              options: models,
              onChanged: (v) => selectedModel.value = v,
            ),
            SizedBox(height: custom.spacing.lg + 4),

            // ---- Actions ----
            Row(
              children: [
                AppPrimaryButton(text: '保存', onPressed: handleSave),
                SizedBox(width: custom.spacing.sm),
                AppSecondaryButton(text: '测试连接', onPressed: () {}),
                const Spacer(),
                AppSecondaryButton(text: '删除配置', onPressed: () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Map provider name to the protocol used in config.json.
  ///
  /// - Anthropic → "anthropic"
  /// - Everything else → "openai_compatible"
  String _protocolFor(String name) {
    if (name == 'Anthropic') return 'anthropic';
    return 'openai_compatible';
  }
}
