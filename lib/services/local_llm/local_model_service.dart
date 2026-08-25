/// 本地模型服务 — 内嵌 llamadart OpenAI 兼容服务
///
/// 职责：
/// 1. 用 llamadart 加载设备端 GGUF 模型（常驻内存）
/// 2. 在本进程内起一个 OpenAI 兼容 HTTP 服务（/v1/models、/v1/chat/completions）
/// 3. 就绪后自动把 `language_models.openai_compatible.local_llm` provider
///    写入 config.json，指向 127.0.0.1 内嵌服务 —— Rust 引擎把它当普通远端模型，
///    工具调用 / 会话入库等能力原样可用
/// 4. 由于 llamadart 单模型单进程且同一时间只能生成一次，请求按 FIFO 排队串行处理
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:llamadart/llamadart.dart';
import 'package:signals/signals.dart';

import 'package:agent/features/settings/models/local_model_info.dart';
import 'package:agent/store/config_store.dart';

/// 本地服务状态。
enum LocalModelStatus { stopped, loading, ready, error }

/// 本地模型服务 — 全局单例。
class LocalModelService {
  LocalModelService._();

  /// 全局唯一实例。
  static final instance = LocalModelService._();

  /// 自动维护的 provider ID（config.json `language_models.openai_compatible.xxx`）。
  static const providerId = 'local_llm';

  /// 默认端口；被占用时尝试顺序递增。
  static const defaultPort = 8947;

  /// 默认上下文长度（未配置时）。
  static const defaultContextSize = 4096;

  LlamaEngine? _engine;
  HttpServer? _server;

  /// 请求队列（llamadart 同一时间只能生成一次，FIFO 串行）。
  final _queue = Queue<HttpRequest>();
  bool _generating = false;

  // ── 响应式状态 ──────────────────────────────────

  final status = signal<LocalModelStatus>(LocalModelStatus.stopped);
  final activeModel = signal<LocalModelInfo?>(null);
  final port = signal<int?>(null);
  final errorMsg = signal<String?>(null);
  final loadingMsg = signal<String?>(null);

  bool get isReady => status.value == LocalModelStatus.ready;

  LocalModelInfo? get current => activeModel.value;

  // ── config.json: local_models 列表 ──────────────

  /// 从 config.json 读取本地模型列表。
  List<LocalModelInfo> readModels() {
    final raw = ConfigStore.instance.data.value['local_models'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => LocalModelInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// 写回本地模型列表到 config.json。
  void saveModels(List<LocalModelInfo> models) {
    ConfigStore.instance.mutate((m) {
      m['local_models'] = [for (final x in models) x.toJson()];
    });
  }

  /// 写入/更新指向内嵌服务的 provider 配置。
  void _writeProviderConfig() {
    final p = port.value;
    final model = activeModel.value;
    if (p == null || model == null) return;
    ConfigStore.instance.mutate((m) {
      final lm =
          m.putIfAbsent('language_models', () => <String, dynamic>{})
              as Map<String, dynamic>;
      final proto =
          lm.putIfAbsent('openai_compatible', () => <String, dynamic>{})
              as Map<String, dynamic>;
      proto[providerId] = {
        'api_url': 'http://127.0.0.1:$p/v1',
        'api_key': 'local-key',
        'available_models': [
          {'name': model.modelId},
        ],
      };
    });
  }

  /// 停止时移除 provider 配置，避免选择器出现失效模型。
  void _removeProviderConfig() {
    ConfigStore.instance.mutate((m) {
      final lm = m['language_models'];
      if (lm is! Map) return;
      final proto = lm['openai_compatible'];
      if (proto is! Map) return;
      proto.remove(providerId);
    });
  }

  // ── 生命周期 ──────────────────────────────────

  /// 加载 [model] 并启动内嵌服务。
  Future<void> start(LocalModelInfo model) async {
    if (_engine != null) await stop();

    activeModel.value = model;
    errorMsg.value = null;
    status.value = LocalModelStatus.loading;
    loadingMsg.value = '加载模型 ${model.label} ...';

    try {
      final engine = LlamaEngine(LlamaBackend());
      final sw = Stopwatch()..start();
      await engine.loadModel(
        model.path,
        modelParams: ModelParams(
          contextSize: model.contextSize,
          maxParallelSequences: 1,
        ),
      );
      _engine = engine;
      loadingMsg.value = '模型已加载（${sw.elapsed.inSeconds}s），启动服务 ...';

      // 绑定端口：默认端口被占用则顺延
      var bound = await _bind(defaultPort);
      bound ??= await _bind(0); // 临时端口
      if (bound == null) {
        throw StateError('无法绑定本地服务端口');
      }
      _server = bound;
      final p = bound.port;
      port.value = p;
      _generating = false;

      unawaited(_serve(bound));
      _writeProviderConfig();
      status.value = LocalModelStatus.ready;
      loadingMsg.value = null;
    } catch (e) {
      activeModel.value = null;
      status.value = LocalModelStatus.error;
      errorMsg.value = '$e';
      await _cleanup();
      rethrow;
    }
  }

  Future<HttpServer?> _bind(int port) async {
    try {
      return await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } catch (_) {
      return null;
    }
  }

  /// 停止服务并卸载模型。
  Future<void> stop() async {
    activeModel.value = null;
    port.value = null;
    errorMsg.value = null;
    status.value = LocalModelStatus.stopped;
    _removeProviderConfig();
    await _cleanup();
  }

  Future<void> _cleanup() async {
    _generating = false;
    final server = _server;
    _server = null;
    try {
      await server?.close(force: true);
    } catch (_) {}
    final engine = _engine;
    _engine = null;
    try {
      await engine?.dispose();
    } catch (_) {}
  }

  // ── HTTP 服务 ──────────────────────────────────

  Future<void> _serve(HttpServer server) async {
    await for (final req in server) {
      unawaited(_dispatch(req));
    }
  }

  Future<void> _dispatch(HttpRequest req) async {
    final path = req.uri.path;
    try {
      if (path == '/v1/models' && req.method == 'GET') {
        _models(req.response);
        return;
      }
      if (path == '/v1/chat/completions' && req.method == 'POST') {
        _queue.add(req);
        _drain();
        return;
      }
      _json(req.response, 404, {'error': {'message': 'not found: $path'}});
    } catch (e) {
      _tryError(req.response, 500, '$e');
    }
  }

  void _models(HttpResponse res) {
    final model = activeModel.value;
    _json(res, 200, {
      'object': 'list',
      'data': [
        {
          'id': model?.modelId ?? 'unknown',
          'object': 'model',
          'created': 0,
          'owned_by': 'local',
        },
      ],
    });
  }

  /// FIFO 队列逐个处理聊天请求。
  Future<void> _drain() async {
    if (_generating) return;
    _generating = true;
    try {
      while (_queue.isNotEmpty) {
        final req = _queue.removeFirst();
        try {
          await _chat(req);
        } catch (e) {
          _tryError(req.response, 500, '$e');
        }
      }
    } finally {
      _generating = false;
    }
  }

  Future<void> _chat(HttpRequest req) async {
    final body =
        jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
    final stream = body['stream'] == true;

    final pendingToolNames = <String, String>{};
    final messages = <LlamaChatMessage>[];
    final rawMessages = body['messages'];
    if (rawMessages is! List) {
      throw const FormatException('`messages` must be an array');
    }
    for (final raw in rawMessages) {
      if (raw is! Map) {
        throw const FormatException('each message must be an object');
      }
      final m = Map<String, dynamic>.from(raw);
      messages.add(_parseMessage(m, pendingToolNames));
      if (m['role'] == 'assistant') {
        for (final tc in messages.last.parts.whereType<LlamaToolCallContent>()) {
          if (tc.id != null) pendingToolNames[tc.id!] = tc.name;
        }
      } else if (m['role'] == 'tool') {
        final tr = messages.last.parts.single as LlamaToolResultContent;
        if (tr.id != null) pendingToolNames.remove(tr.id);
      }
    }

    final tools = _parseTools(body['tools']);

    // MiniCPM 等模型通过 enable_thinking 控制思考模式；
    // 透传给 llamadart 的模板渲染（enableThinking）与 Jinja kwargs 双通道。
    // OpenAI 兼容标准：reasoning_effort == "none" 也可关思考（Rust 端标题生成等轻量任务走此开关）
    final reasoningEffort = body['reasoning_effort'];
    final enableThinking = body['enable_thinking'] != false && reasoningEffort != "none";

    final engine = _engine;
    if (engine == null) {
      throw StateError('本地模型未加载');
    }

    final chunks = engine.create(
      messages,
      tools: tools,
      enableThinking: enableThinking,
      chatTemplateKwargs: {'enable_thinking': enableThinking},
      params: GenerationParams(
        // 优先请求体显式 max_tokens；未传时用模型配置（界面可编辑），
        // 再兜底 4096。思考模式（enable_thinking）下思考内容也计入额度。
        maxTokens:
            (body['max_tokens'] as num?)?.toInt() ??
            activeModel.value?.maxTokens ??
            4096,
        temp: (body['temperature'] as num?)?.toDouble() ?? 0.7,
        topP: (body['top_p'] as num?)?.toDouble() ?? 0.9,
        seed: (body['seed'] as num?)?.toInt(),
        // 逐 token 流式：默认按 8 token/512 字节攒批，导致界面大块输出；
        // 置 1 让每个 token 立即经 isolate 发送（本地服务据此逐块 SSE flush）。
        streamBatchTokenThreshold: 1,
        streamBatchByteThreshold: 1,
      ),
    );

    if (!stream) {
      final sb = StringBuffer();
      final thinkingSb = StringBuffer();
      String? finishReason;
      final toolCalls = <LlamaCompletionChunkToolCall>[];
      await for (final c in chunks) {
        final choice = c.choices.first;
        final d = choice.delta;
        if (d.content != null) sb.write(d.content);
        if (d.thinking != null) thinkingSb.write(d.thinking);
        if (d.toolCalls != null) toolCalls.addAll(d.toolCalls!);
        finishReason = choice.finishReason;
      }
      final message = <String, dynamic>{
        'role': 'assistant',
        if (thinkingSb.isNotEmpty) 'reasoning_content': thinkingSb.toString(),
        if (toolCalls.isEmpty)
          'content': sb.toString()
        else
          'content': null,
        if (toolCalls.isNotEmpty)
          'tool_calls': [
            for (final tc in toolCalls)
              {
                'id': tc.id,
                'type': 'function',
                'function': {
                  'name': tc.function?.name,
                  'arguments': tc.function?.arguments,
                },
              },
          ],
      };
      _json(req.response, 200, {
        'id': 'chatcmpl-local',
        'object': 'chat.completion',
        'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'model': activeModel.value?.modelId,
        'choices': [
          {'index': 0, 'message': message, 'finish_reason': finishReason ?? 'stop'},
        ],
        'usage': {'prompt_tokens': 0, 'completion_tokens': 0, 'total_tokens': 0},
      });
      return;
    }

    // SSE 流式
    req.response.headers
      ..contentType = ContentType('text', 'event-stream', charset: 'utf-8')
      ..set('Cache-Control', 'no-cache')
      ..set('Connection', 'keep-alive');
    var idx = 0;
    try {
      await for (final c in chunks) {
        final d = c.choices.first.delta;
        final chunk = {
          'id': 'chatcmpl-$idx',
          'object': 'chat.completion.chunk',
          'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'model': activeModel.value?.modelId,
          'choices': [
            {
              'index': 0,
              'delta': {
                if (idx == 0) 'role': 'assistant',
                if (d.thinking != null) 'reasoning_content': d.thinking,
                if (d.content != null) 'content': d.content,
                if (d.toolCalls != null)
                  'tool_calls': [
                    for (final tc in d.toolCalls!)
                      {
                        'index': tc.index,
                        'id': tc.id,
                        'type': tc.type,
                        'function': {
                          'name': tc.function?.name,
                          'arguments': tc.function?.arguments,
                        },
                      },
                  ],
              },
              'finish_reason': c.choices.first.finishReason,
            },
          ],
        };
        req.response.write('data: ${jsonEncode(chunk)}\n\n');
        await req.response.flush();
        idx++;
      }
    } catch (_) {
      // 生成中断：干净地终止 SSE，避免客户端挂起
      req.response.write('data: [DONE]\n\n');
      await req.response.close();
      return;
    }
    req.response.write('data: [DONE]\n\n');
    await req.response.close();
  }

  // ── OpenAI 消息 / 工具解析 ──────────────────────

  LlamaChatMessage _parseMessage(
    Map<String, dynamic> m,
    Map<String, String> pendingToolNames,
  ) {
    final roleRaw = m['role'];
    final role = switch (roleRaw) {
      'system' => LlamaChatRole.system,
      'user' => LlamaChatRole.user,
      'assistant' => LlamaChatRole.assistant,
      'tool' => LlamaChatRole.tool,
      _ => throw FormatException('unsupported role: $roleRaw'),
    };

    if (role == LlamaChatRole.tool) {
      final content = m['content'];
      final result = content is String
          ? content
          : content is List
          ? content
                .whereType<Map>()
                .map((p) => p['text']?.toString() ?? '')
                .join('\n')
          : '';
      final name = (m['name'] as String?) ??
          (m['tool_call_id'] != null
              ? pendingToolNames[m['tool_call_id'] as String] ?? ''
              : '');
      return LlamaChatMessage.withContent(
        role: role,
        content: [
          LlamaToolResultContent(
            id: m['tool_call_id'] as String?,
            name: name,
            result: result,
          ),
        ],
      );
    }

    final parts = <LlamaContentPart>[];
    final content = m['content'];
    if (content is String && content.isNotEmpty) {
      parts.add(LlamaTextContent(content));
    } else if (content is List) {
      for (final p in content) {
        if (p is Map && p['type'] == 'text') {
          parts.add(LlamaTextContent(p['text']?.toString() ?? ''));
        }
      }
    }

    if (role == LlamaChatRole.assistant) {
      final reasoning = m['reasoning_content'];
      if (reasoning is String && reasoning.trim().isNotEmpty) {
        parts.add(LlamaThinkingContent(reasoning.trim()));
      }
      final toolCalls = m['tool_calls'];
      if (toolCalls is List) {
        for (final tc in toolCalls) {
          if (tc is! Map) continue;
          final f = tc['function'];
          if (f is! Map) continue;
          final name = f['name']?.toString() ?? '';
          final args = f['arguments']?.toString() ?? '';
          Map<String, dynamic> argsMap;
          try {
            final decoded = jsonDecode(args);
            argsMap = decoded is Map
                ? Map<String, dynamic>.from(decoded)
                : <String, dynamic>{};
          } catch (_) {
            argsMap = <String, dynamic>{};
          }
          parts.add(
            LlamaToolCallContent(
              id: tc['id'] as String?,
              name: name,
              arguments: argsMap,
              rawJson: args,
            ),
          );
        }
      }
    }

    if (parts.isEmpty) {
      parts.add(const LlamaTextContent(''));
    }
    return LlamaChatMessage.withContent(role: role, content: parts);
  }

  List<ToolDefinition>? _parseTools(Object? rawTools) {
    if (rawTools is! List || rawTools.isEmpty) return null;
    final tools = <ToolDefinition>[];
    for (final raw in rawTools) {
      if (raw is! Map) continue;
      final f = raw['function'];
      if (f is! Map) continue;
      final name = f['name']?.toString() ?? '';
      if (name.isEmpty) continue;
      tools.add(
        ToolDefinition(
          name: name,
          description: f['description']?.toString() ?? '',
          parameters: _parseToolParams(f['parameters']),
          handler: (params) async => throw LlamaUnsupportedException(
            '工具由 API 客户端执行，请在后续请求中提交 tool 结果',
          ),
        ),
      );
    }
    return tools.isEmpty ? null : tools;
  }

  List<ToolParam> _parseToolParams(Object? raw) {
    if (raw is! Map) return const [];
    final properties = raw['properties'];
    if (properties is! Map) return const [];
    final requiredSet = (raw['required'] as List? ?? const [])
        .whereType<String>()
        .toSet();
    final result = <ToolParam>[];
    for (final entry in properties.entries) {
      final name = entry.key;
      final schema = entry.value;
      if (schema is! Map) continue;
      result.add(
        _mapToolParam(
          name,
          Map<String, dynamic>.from(schema),
          required: requiredSet.contains(name),
        ),
      );
    }
    return result;
  }

  ToolParam _mapToolParam(
    String name,
    Map<String, dynamic> schema, {
    required bool required,
  }) {
    final description = schema['description'] as String?;
    final type = schema['type']?.toString();
    switch (type) {
      case 'string':
        final values = schema['enum'];
        if (values is List && values.isNotEmpty) {
          return ToolParam.enumType(
            name,
            values: values.map((v) => v.toString()).toList(),
            description: description,
            required: required,
          );
        }
        return ToolParam.string(
          name,
          description: description,
          required: required,
        );
      case 'integer':
        return ToolParam.integer(
          name,
          description: description,
          required: required,
        );
      case 'number':
        return ToolParam.number(
          name,
          description: description,
          required: required,
        );
      case 'boolean':
        return ToolParam.boolean(
          name,
          description: description,
          required: required,
        );
      case 'array':
        final items = schema['items'];
        final itemType = items is Map
            ? _mapToolParam(name, Map<String, dynamic>.from(items), required: false)
            : ToolParam.string(name);
        return ToolParam.array(
          name,
          itemType: itemType,
          description: description,
          required: required,
        );
      case 'object':
        final props = schema['properties'];
        final children = <ToolParam>[];
        if (props is Map) {
          final childRequired = (schema['required'] as List? ?? const [])
              .whereType<String>()
              .toSet();
          for (final e in props.entries) {
            if (e.value is! Map) continue;
            children.add(
              _mapToolParam(
                e.key,
                Map<String, dynamic>.from(e.value as Map),
                required: childRequired.contains(e.key),
              ),
            );
          }
        }
        return ToolParam.object(
          name,
          properties: children,
          description: description,
          required: required,
        );
      default:
        return ToolParam.string(
          name,
          description: description,
          required: required,
        );
    }
  }

  // ── 响应工具 ──────────────────────────────────

  void _json(HttpResponse res, int status, Object body) {
    res.statusCode = status;
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode(body));
    res.close();
  }

  void _tryError(HttpResponse res, int status, String message) {
    try {
      _json(res, status, {
        'error': {'message': message},
      });
    } catch (_) {
      // headers 已发出，直接关闭连接
      res.close();
    }
  }
}
