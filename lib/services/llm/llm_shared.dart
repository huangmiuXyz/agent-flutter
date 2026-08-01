/// LLM Service 共享类型
library;

/// LLM 服务异常
class LlmException implements Exception {
  final String message;
  const LlmException(this.message);

  @override
  String toString() => 'LlmException: $message';
}

/// LLM API mixin 公共基座 — 提供初始化检查与统一的错误包装。
///
/// 所有 `api.xxx` 调用通过 [guard] 包一层，失败时抛出带业务语义的
/// [LlmException]，避免每个方法重复 try/catch 样板。
mixin GuardedApi {
  /// 子类必须提供初始化检查（在 [guard] 内、调用 Rust API 之前执行）。
  void ensureInitialized();

  /// 调用 Rust API 并统一处理异常。
  ///
  /// [message] 是业务语义前缀（如「获取会话列表失败」），
  /// 失败时抛出 `LlmException('$message: $e')`。
  Future<T> guard<T>(String message, Future<T> Function() fn) async {
    ensureInitialized();
    try {
      return await fn();
    } catch (e) {
      throw LlmException('$message: $e');
    }
  }
}
