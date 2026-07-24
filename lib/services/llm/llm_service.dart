/// Agent LLM Service
///
/// 提供层，封装 `flutter_rust_bridge` 生成的 Rust API 调用，
/// 在 Dart 侧提供类型安全、错误清晰的接口。
///
/// 方法按领域拆分到以下 mixin：
/// - [ProviderModelApi] — 提供商与模型列表
/// - [ChatApi] — 非流式/流式聊天
/// - [SessionApi] — 会话 CRUD、数据读取、实时订阅
library;

import 'llm_chat_api.dart';
import 'llm_provider_api.dart';
import 'llm_session_api.dart';

/// LLM 服务 — 所有与 Rust 引擎的交互通过此类进行
///
/// 单例模式：无论 provider 如何重建，始终返回同一实例。
class LlmService with ProviderModelApi, ChatApi, SessionApi {
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

  /// 确保已初始化（mixin 通过此方法检查）
  @override
  void ensureInitialized() {
    if (!_initialized) {
      _initialized = true;
    }
  }
}
