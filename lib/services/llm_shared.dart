/// LLM Service 共享类型
library;

/// LLM 服务异常
class LlmException implements Exception {
  final String message;
  const LlmException(this.message);

  @override
  String toString() => 'LlmException: $message';
}
