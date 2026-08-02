/// Provider config page — API Key, Endpoint, 协议类型, default model settings.
///
/// Persists to config.json via [ConfigFileStore]:
///   language_models.{protocol}.{id}.api_url
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
import 'package:agent/widgets/select/app_select.dart';
import 'package:agent/widgets/switch/app_switch.dart';
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
    // 联网搜索：服务端搜索工具（仅对支持的协议生效，如 OpenAI Responses / Anthropic）
    // openai_compatible（chat completions）不提供服务端联网搜索，禁用该选项
    final webSearch = useState(false);
    // 协议类型：默认按提供商名推断，可从现有配置检测实际所在段
    final protocol = useState<String?>(protocolForProvider(provider.name));

    // 订阅 config 变化，跨窗口同步后重新加载表单
    final configVersion = useExistingSignal(ConfigStore.instance.data).value;

    // ── Load existing config on mount or config change ──
    useEffect(() {
      try {
        // 从任意段检测 provider 实际所在协议段
        final detected = protocolFromConfig(
          ConfigStore.instance.data.value,
          provider.name,
        );
        if (detected != null) {
          protocol.value = detected;
        }
        final section = findProviderConfig(
          ConfigStore.instance.data.value,
          provider.name,
        );
        if (section != null) {
          final url = section['api_url'] as String?;
          if (url != null && url.isNotEmpty) {
            endpointCtrl.text = url;
          }
          final key = section['api_key'] as String?;
          if (key != null && key.isNotEmpty) {
            apiKeyCtrl.text = key;
          }
          final ws = section['web_search'];
          webSearch.value = ws == true || ws is Map;
        }
      } catch (_) {}
      return null;
    }, [configVersion, provider.name]);

    // ── Save handler ──
    Future<void> handleSave() async {
      final newProtocol = protocol.value;
      if (newProtocol == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('请选择协议类型')));
        }
        return;
      }

      try {
        ConfigStore.instance.mutate((m) {
          final languageModels =
              m.putIfAbsent('language_models', () => <String, dynamic>{})
                  as Map<String, dynamic>;

          // 从其他协议段移除旧配置（协议变更时迁移）
          final oldProtocol = protocolFromConfig(m, provider.name);
          if (oldProtocol != null && oldProtocol != newProtocol) {
            final oldSection =
                languageModels[oldProtocol] as Map<String, dynamic>?;
            if (oldSection != null) {
              oldSection.remove(provider.name);
              if (oldSection.isEmpty) {
                languageModels.remove(oldProtocol);
              }
            }
          }

          // 写入新协议段
          final protocolConfig =
              languageModels.putIfAbsent(newProtocol, () => <String, dynamic>{})
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
          // openai_compatible 不支持服务端联网搜索，不写入（并清理历史残留）
          if (webSearch.value && newProtocol != 'openai_compatible') {
            cfg['web_search'] = true;
          } else {
            cfg.remove('web_search');
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
        primary: [AppPrimaryButton(text: '保存', onPressed: handleSave)],
        secondary: [
          // 始终显示：从聊天页选择器跳转时也可能携带未标记 configured 的
          // ProviderInfo，但按钮操作本身与 configured 状态无关
          AppSecondaryButton(text: '管理模型', onPressed: onManageModels),
          AppSecondaryButton(
            text: '删除配置',
            onPressed: () => _handleDelete(context),
          ),
        ],
      ),
      children: [
        AppSelect<String>(
          label: '协议类型',
          placeholder: '选择 API 协议',
          value: protocol.value,
          options: protocolOptions,
          onChanged: (v) {
            protocol.value = v;
            // 切换到 openai_compatible 时联网搜索不可用，清空勾选避免误保存
            if (v == 'openai_compatible') {
              webSearch.value = false;
            }
          },
        ),
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
        AppSwitch(
          value: webSearch.value,
          onChanged: (v) => webSearch.value = v,
          disabled: protocol.value == 'openai_compatible',
          label: '启用联网搜索（服务端执行，仅 Anthropic / OpenAI Responses 协议支持）',
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
        // 从所有协议段移除该 provider 的配置
        final models = data['language_models'] as Map<String, dynamic>?;
        if (models != null) {
          final toRemove = <String>[];
          for (final entry in models.entries) {
            final section = entry.value as Map<String, dynamic>?;
            if (section != null && section.containsKey(provider.name)) {
              section.remove(provider.name);
              if (section.isEmpty) toRemove.add(entry.key);
            }
          }
          for (final key in toRemove) {
            models.remove(key);
          }
          if (models.isEmpty) {
            data.remove('language_models');
          }
        }
      });

      debugPrint('Deleted provider config: ${provider.name}');

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
