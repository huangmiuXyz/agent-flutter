/// 本地模型流式输出测试脚本
///
/// 用法（在项目根目录）:
///   dart run tools/stream_test.dart [选项] ["提示词"]
///
/// 选项:
///   --port=8947         本地服务端口（默认 8947）
///   --model=xxx         模型 ID（默认留空自动忽略，服务端不校验）
///   --max-tokens=512    最大生成 token 数（拉大可看到更多流式过程）
///   --no-stream         发送非流式请求做对比
///   --thinking          带 enable_thinking: true（MiniCPM 思考模式）
///   --tools             带工具定义（复现应用真实请求路径：引擎请求始终带 tools，
///                       会走 llamadart parseToolCallsEnabled=true 的节流分支）
///
/// 工作原理: 发 stream:true 请求，逐 SSE 事件记录到达时间，
/// 分析 chunk 间隔分布，据此判断是真流式（逐步到达）还是
/// 一次性输出（全部瞬间到达）。
library;

import 'dart:convert';
import 'dart:io';

const _defaultPort = 8947;

/// 模拟应用引擎使用的示例工具（get_weather），仅用于触发工具解析分支。
const _sampleTools = [
  {
    'type': 'function',
    'function': {
      'name': 'get_weather',
      'description': '获取指定城市的天气',
      'parameters': {
        'type': 'object',
        'properties': {
          'city': {'type': 'string', 'description': '城市名'},
        },
        'required': ['city'],
      },
    },
  },
];

Future<void> main(List<String> args) async {
  var port = _defaultPort;
  var model = '';
  var prompt = '你好';
  var maxTokens = 512;
  var stream = true;
  var enableThinking = false;
  var withTools = false;

  for (final arg in args) {
    if (arg.startsWith('--port=')) {
      port = int.tryParse(arg.substring(7)) ?? _defaultPort;
    } else if (arg.startsWith('--model=')) {
      model = arg.substring(8);
    } else if (arg.startsWith('--max-tokens=')) {
      maxTokens = int.tryParse(arg.substring(13)) ?? 512;
    } else if (arg == '--no-stream') {
      stream = false;
    } else if (arg == '--thinking') {
      enableThinking = true;
    } else if (arg == '--tools') {
      withTools = true;
    } else {
      prompt = arg;
    }
  }

  final body = <String, dynamic>{
    'model': model,
    'stream': stream,
    'max_tokens': maxTokens,
    if (enableThinking) 'enable_thinking': true,
    if (withTools) 'tools': _sampleTools,
    'messages': [
      {'role': 'user', 'content': prompt},
    ],
  };

  stdout.writeln('=== 本地模型流式测试 ===');
  stdout.writeln('目标: http://127.0.0.1:$port/v1/chat/completions');
  stdout.writeln('model: ${model.isEmpty ? "(服务端当前模型)" : model}');
  stdout.writeln('stream: $stream  max_tokens: $maxTokens  enable_thinking: $enableThinking  tools: $withTools');
  stdout.writeln('prompt: $prompt');
  stdout.writeln('');

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  final sw = Stopwatch()..start();

  try {
    final req = await client.post(
      '127.0.0.1',
      port,
      '/v1/chat/completions',
    );
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));

    final res = await req.close();
    if (res.statusCode != 200) {
      stdout.writeln('HTTP ${res.statusCode}: ${await utf8.decoder.bind(res).join()}');
      return;
    }

    if (!stream) {
      // 非流式：一次性读完整响应，只演示对比
      final text = await utf8.decoder.bind(res).join();
      final elapsed = sw.elapsedMilliseconds;
      final data = jsonDecode(text) as Map<String, dynamic>;
      final content = (data['choices'] as List).first['message']['content'];
      stdout.writeln('非流式响应: 总耗时 ${elapsed}ms, 内容长度 ${content?.toString().length ?? 0} 字符');
      stdout.writeln('content: $content');
      stdout.writeln('结论: 非流式请求 — 一次性返回，无逐块输出');
      return;
    }

    // ── 流式：逐 SSE 事件分析 ────────────────────
    final contentType = res.headers.contentType;
    if (contentType == null ||
        contentType.mimeType != 'text/event-stream') {
      stdout.writeln('警告: 响应 Content-Type 不是 text/event-stream ($contentType)');
    }

    final events = <_Event>[];
    final lines = utf8.decoder.bind(res).transform(const LineSplitter());

    await for (final line in lines) {
      final trimmed = line.trimRight();
      if (!trimmed.startsWith('data:')) continue;
      final data = trimmed.substring(5).trim();
      if (data.isEmpty) continue;

      final at = sw.elapsedMilliseconds;
      if (data == '[DONE]') {
        events.add(_Event(at: at, raw: '[DONE]'));
        continue;
      }

      String? contentDelta;
      String? thinkingDelta;
      String? role;
      String? finishReason;
      bool emptyDelta = false;
      try {
        final decoded = jsonDecode(data) as Map<String, dynamic>;
        final choices = decoded['choices'] as List? ?? const [];
        if (choices.isNotEmpty) {
          final choice = choices.first as Map<String, dynamic>;
          finishReason = choice['finish_reason'] as String?;
          final delta = choice['delta'] as Map<String, dynamic>?;
          if (delta != null) {
            role = delta['role'] as String?;
            contentDelta = delta['content'] as String?;
            thinkingDelta = delta['reasoning_content'] as String?;
            if (delta.isEmpty) emptyDelta = true;
          }
        }
      } catch (e) {
        contentDelta = '(解析失败: $e)';
      }
      events.add(
        _Event(
          at: at,
          raw: data.length < 200 ? data : '${data.substring(0, 200)}…',
          content: contentDelta,
          thinking: thinkingDelta,
          role: role,
          finishReason: finishReason,
          empty: emptyDelta,
        ),
      );
    }

    // ── 统计与报告 ──────────────────────────────
    final totalMs = sw.elapsedMilliseconds;
    final contentItems = events.where((e) => e.content?.isNotEmpty ?? false).toList();
    final thinkingItems = events.where((e) => e.thinking?.isNotEmpty ?? false).toList();
    final emptyItems = events.where((e) => e.empty).toList();
    final doneMs = events.isEmpty ? totalMs : events.last.at;

    // 按 500ms 分桶显示 thinking/content 事件分布（看清到达节奏）
    void dumpBuckets(String label, List<_Event> items) {
      if (items.isEmpty) {
        stdout.writeln('$label: (无)');
        return;
      }
      final bucketMs = 500;
      final buckets = <int, int>{};
      for (final e in items) {
        buckets.update(e.at ~/ bucketMs, (c) => c + 1, ifAbsent: () => 1);
      }
      final keys = buckets.keys.toList()..sort();
      final sb = StringBuffer('$label ($label各块字符数): ');
      for (final k in keys) {
        final eventsInBucket = buckets[k]!;
        final chars = items
            .where((e) => e.at ~/ bucketMs == k)
            .fold<int>(0, (s, e) => s + (e.content?.length ?? e.thinking?.length ?? 0));
        sb.write('${k * bucketMs}-${k * bucketMs + bucketMs}ms×$eventsInBucket块($chars字) ');
      }
      stdout.writeln(sb.toString());
    }

    stdout.writeln();
    dumpBuckets('thinking', thinkingItems);
    dumpBuckets('content', contentItems);

    final totalContent = contentItems.fold<int>(0, (sum, e) => sum + e.content!.length);
    final totalThinking = thinkingItems.fold<int>(0, (sum, e) => sum + e.thinking!.length);

    stdout.writeln('总耗时: ${totalMs}ms （首个事件 ${events.firstOrNull?.at ?? 0}ms，末事件 ${doneMs}ms）');
    stdout.writeln('事件总数: ${events.length}');
    stdout.writeln('  内容事件: ${contentItems.length}  思考事件: ${thinkingItems.length}  空delta: ${emptyItems.length}');
    stdout.writeln('内容总字符: $totalContent  思考总字符: $totalThinking');

    if (contentItems.isNotEmpty) {
      final intervals = <int>[];
      var prev = contentItems.first.at;
      var min = 1 << 30, max = 0;
      var nearZero = 0; // <5ms 的块数
      for (final e in contentItems.skip(1)) {
        final gap = e.at - prev;
        intervals.add(gap);
        prev = e.at;
      }
      final avg = intervals.isEmpty
          ? 0
          : intervals.reduce((a, b) => a + b) ~/ intervals.length;
      for (final g in intervals) {
        min = g < min ? g : min;
        max = g > max ? g : max;
        if (g < 5) nearZero++;
      }
      stdout.writeln('内容事件间隔: min=${min}ms max=${max}ms avg=${avg}ms  (<5ms的块: $nearZero/${intervals.length})');
      stdout.writeln('平均每块字符: ${totalContent ~/ contentItems.length}');
    }

    // 明细（最多 40 条，超了只列前 20 和后 20）
    List<_Event> visible;
    if (events.length <= 40) {
      visible = events;
    } else {
      visible = [...events.take(20), _Event(at: -1, raw: '…中间省略…'), ...events.skip(events.length - 20)];
    }
    stdout.writeln('');
    stdout.writeln('--- 事件明细 ---');
    for (final e in visible) {
      final tag = e.raw == '[DONE]'
          ? '[DONE]'
          : e.role != null
              ? 'role=${e.role}'
              : e.thinking?.isNotEmpty == true
                  ? 'thinking:+${e.thinking!.length}'
                  : e.content?.isNotEmpty == true
                      ? 'content:+${e.content!.length}'
                      : e.finishReason != null
                          ? 'finish=${e.finishReason}'
                          : '(空)';
      final ts = e.at < 0 ? '' : (e.at < 1000 ? ' ${e.at}ms' : '${e.at}ms');
      stdout.writeln('[$ts] $tag');
    }

    // ── 结论 ────────────────────────────────────
    stdout.writeln('');
    final contentSpread = contentItems.isEmpty ? 0 : contentItems.last.at - contentItems.first.at;
    stdout.writeln('=== 结论 ===');
    if (contentItems.length <= 1 && contentSpread <= 20) {
      stdout.writeln('❌ 一次性输出: 内容几乎在单一时刻到达（${contentItems.length} 块，跨度 ${contentSpread}ms），不是流式。');
    } else if (contentSpread > 50) {
      stdout.writeln('✅ 真流式: 内容分 ${contentItems.length} 块逐步到达，跨度 ${contentSpread}ms，有明显节奏。');
    } else {
      stdout.writeln('⚠️ 弱流式: 内容分多块，但跨度仅 ${contentSpread}ms（生成太快），肉眼难辨逐块。');
    }
  } catch (e) {
    stdout.writeln('请求失败: $e');
    stdout.writeln('（确认本地服务已启动: 界面显示「端口 $port」）');
  } finally {
    client.close(force: true);
  }
}

class _Event {
  final int at;
  final String raw;
  final String? content;
  final String? thinking;
  final String? role;
  final String? finishReason;
  final bool empty;

  const _Event({
    required this.at,
    required this.raw,
    this.content,
    this.thinking,
    this.role,
    this.finishReason,
    this.empty = false,
  });
}