import 'package:signals/signals.dart';

import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/store/config_store.dart';
import 'package:agent/services/llm/llm_service.dart';

class LlmStore {
  static final instance = LlmStore._();
  LlmStore._();

  final service = LlmService();
  final initialized = signal(false);

  final currentProvider = computed<String>(() {
    final dm = ConfigStore.instance.data.value['default_model'];
    if (dm is Map) return dm['provider'] as String? ?? '';
    return '';
  });

  final currentModel = computed<String>(() {
    final dm = ConfigStore.instance.data.value['default_model'];
    if (dm is Map) return dm['model'] as String? ?? '';
    return '';
  });

  final providers = signal(<api.ProviderSummary>[]);
  final providersLoading = signal(true);

  final models = signal(<String>[]);
  final modelsLoading = signal(true);

  Future<void> init() async {
    await service.init();
    initialized.value = true;
    await loadProviders();
  }

  Future<void> loadProviders() async {
    providersLoading.value = true;
    try {
      providers.value = await service.listProviders(
        configPath: ConfigStore.instance.configPath,
      );
    } finally {
      providersLoading.value = false;
    }
  }

  Future<void> loadModels() async {
    if (currentProvider.value.isEmpty) return;
    modelsLoading.value = true;
    try {
      models.value = await service.listModels(
        provider: currentProvider.value,
        configPath: ConfigStore.instance.configPath,
      );
    } finally {
      modelsLoading.value = false;
    }
  }
}
