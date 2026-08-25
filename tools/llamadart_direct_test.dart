/// 直接用 llamadart（patch 版）加载本地模型，观测 content / thinking
/// 是否逐 token 流式输出。绕开 HTTP 服务，直测生成端。
///
/// 用法:
///   dart run tools/llamadart_direct_test.dart <gguf路径> "<提示词>"
///   （--tools 参数带上工具定义，复现应用真实路径）
import 'dart:io';

import 'package:llamadart/llamadart.dart';

Future<void> main(List<String> args) async {
  final modelPath = args.isNotEmpty ? args[0] : '';
  final withTools = args.contains('--tools');
  final prompt =
      args.length > 1 && !args[1].startsWith('--') ? args[1] : '你好';
  if (modelPath.isEmpty) {
    stdout.writeln('用法: dart run tools/llamadart_direct_test.dart <gguf路径> ["提示词"] [--tools]');
    return;
  }

  LlamaLogger.instance.setLevel(LlamaLogLevel.debug);
  LlamaLogger.instance.setHandler((record) {
    if (record.message.contains('PATCH-DEBUG')) {
      stdout.writeln('[llamadart] ${record.message}');
    }
  });

  stdout.writeln('加载模型: $modelPath');
  final engine = LlamaEngine(LlamaBackend());
  final sw = Stopwatch()..start();
  try {
    await engine.loadModel(
      modelPath,
      modelParams: const ModelParams(contextSize: 2048, maxParallelSequences: 1),
    );
    stdout.writeln('模型加载完成: ${sw.elapsedMilliseconds}ms');
    sw.reset();

    final messages = [
      LlamaChatMessage.fromText(role: LlamaChatRole.user, text: prompt),
    ];

    final tools = withTools
        ? [
            ToolDefinition(
              name: 'get_weather',
              description: '获取指定城市的天气',
              parameters: [
                ToolParam.string('city', description: '城市名', required: true),
              ],
              handler: (params) async => 'sunny',
            ),
          ]
        : null;

    // 思考 open + 逐 token 批阈值
    final chunks = engine.create(
      messages,
      tools: tools,
      enableThinking: true,
      chatTemplateKwargs: const {'enable_thinking': true},
      params: const GenerationParams(
        maxTokens: 2048,
        streamBatchTokenThreshold: 1,
        streamBatchByteThreshold: 1,
      ),
    );

    stdout.writeln('--- 生成（每 chunk 一行: [+ms] thinking/内容 +N字符）---');
    var contentChars = 0;
    var thinkingChars = 0;
    var chunkCount = 0;
    var firstThinkingAt = -1;
    var firstContentAt = -1;
    final thinkingTimes = <int>[];
    final contentTimes = <int>[];

    await for (final c in chunks) {
      chunkCount++;
      final delta = c.choices.first.delta;
      final at = sw.elapsedMilliseconds;
      if (delta.thinking != null && delta.thinking!.isNotEmpty) {
        thinkingChars += delta.thinking!.length;
        if (firstThinkingAt < 0) firstThinkingAt = at;
        thinkingTimes.add(at);
        stdout.writeln('[${at}ms] thinking:+${delta.thinking!.length}');
      }
      if (delta.content != null && delta.content!.isNotEmpty) {
        contentChars += delta.content!.length;
        if (firstContentAt < 0) firstContentAt = at;
        contentTimes.add(at);
        stdout.writeln('[${at}ms] content:+${delta.content!.length}');
      }
    }

    stdout.writeln('--- 统计 ---');
    stdout.writeln('chunk 总数: $chunkCount');
    stdout.writeln('thinking: ${thinkingChars}字符, ${thinkingTimes.length}块, 首块 ${firstThinkingAt}ms, 跨度 ${thinkingTimes.isEmpty ? 0 : thinkingTimes.last - firstThinkingAt}ms');
    stdout.writeln('content:  $contentChars字符, ${contentTimes.length}块, 首块 ${firstContentAt}ms, 跨度 ${contentTimes.isEmpty ? 0 : contentTimes.last - firstContentAt}ms');
    if (contentTimes.length > 1) {
      // 看 content 是否集中在尾部（最后 20% 时间/块数占大部分）
      final totalSpan = contentTimes.last - contentTimes.first;
      final tailFrom = contentTimes.first + totalSpan * 4 ~/ 5;
      final tailCount = contentTimes.where((t) => t >= tailFrom).length;
      stdout.writeln('content 尾部(最后1/5时间)块数: $tailCount/${contentTimes.length}');
    }

    await engine.dispose();
  } catch (e) {
    stdout.writeln('错误: $e');
    try {
      await engine.dispose();
    } catch (_) {}
  }
}