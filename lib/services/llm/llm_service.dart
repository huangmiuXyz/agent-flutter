/// Agent LLM Service
///
/// 提供层，封装 `flutter_rust_bridge` 生成的 Rust API 调用，
/// 在 Dart 侧提供类型安全、错误清晰的接口。
///
/// 方法按领域拆分到以下 mixin（共同依赖 [GuardedApi] 提供初始化检查与错误包装）：
/// - [ProviderModelApi] — 提供商与模型列表
/// - [ChatApi] — 非流式/流式聊天
/// - [SessionApi] — 会话 CRUD、数据读取、实时订阅
library;

import 'llm_chat_api.dart';
import 'llm_provider_api.dart';
import 'llm_session_api.dart';
import 'llm_shared.dart';

/// LLM 服务 — 所有与 Rust 引擎的交互通过此类进行
///
/// 单例模式：无论 provider 如何重建，始终返回同一实例。
class LlmService with GuardedApi, ProviderModelApi, ChatApi, SessionApi {
  static final LlmService _instance = LlmService._internal();

  /// 返回全局唯一实例
  factory LlmService() => _instance;

  LlmService._internal();

  bool _initialized = false;

  /// 初始化 Rust 引擎（FRB 运行时）
  Future<void> init() async {
    if (_initialized) return;
    // Rust bridge 已在 main.dart 中初始化
    _initialized = true;
  }

  /// 确保已初始化（[GuardedApi.guard] 在调用 Rust API 前检查）
  ///
  /// 注意：Rust bridge 已在 main.dart 中初始化，此处仅保持幂等标记。
  @override
  void ensureInitialized() {
    if (!_initialized) {
      _initialized = true;
    }
  }
}
