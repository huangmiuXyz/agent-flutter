/// 前端工具注册入口
///
/// 在应用启动时调用 [registerFrontendTools]，向 Rust 后端注册前端工具
/// 并在 [EngineClient] 注册对应 handler。
///
/// 当前注册的工具：
/// - `simulated_terminal` — 在终端中执行命令并返回输出，支持通过 id 复用终端
/// - `terminal_send_input` — 向指定终端发送原始输入（回答交互式提示）
library;

import 'dart:convert';

import 'package:nanoid/nanoid.dart';

import 'package:agent/services/engine/engine_client.dart';
import 'package:agent/services/llm/llm_service.dart';
import 'package:agent/store/xterm_store.dart';
import 'package:agent/utils/shell_utils.dart';
import 'package:agent/rust_bridge/events.dart';

/// 注册所有前端工具到 Rust 后端 + EngineClient。
///
/// 在 `main.dart` 主窗口启动时调用一次。
Future<void> registerFrontendTools() async {
  registerSimulatedTerminal();
  registerTerminalSendInput();
}

/// 注册 `simulated_terminal` 工具。
///
/// 工具 schema：
/// ```json
/// {
///   "type": "object",
///   "properties": {
///     "command": { "type": "string", "description": "要执行的 shell 命令" },
///     "terminal_id": {
///       "type": "string",
///       "description": "可选。复用已有终端的 id。首次调用不传会创建新终端并返回 id；后续调用传入此 id 可复用终端（保留工作目录、env 等）。如果该终端已被用户关闭，会返回错误，需不传 id 重新创建。"
///     }
///   },
///   "required": ["command"]
/// }
/// ```
///
/// 行为：
/// 1. 不传 `terminal_id` → 创建新终端 tab，返回 id + 输出
/// 2. 传 `terminal_id` 且存在 → 复用终端（保留 shell 状态），返回输出
/// 3. 传 `terminal_id` 但已关闭 → 返回错误，提示 AI 不传 id 重新创建
void registerSimulatedTerminal() {
  const toolName = 'simulated_terminal';
  const description =
      '在用户终端中执行 shell 命令并返回输出。'
      '适用于查看文件、运行脚本、检查环境等场景。'
      '命令在持久的 shell 会话中执行，工作目录和环境变量会保留。'
      '首次调用不传 terminal_id 会创建新终端并在返回中包含 id；'
      '后续调用传入该 id 可复用终端。'
      '如果终端被用户关闭，调用会失败，需不传 id 创建新终端。';
  const parameters = r'''
{
  "type": "object",
  "properties": {
    "command": {
      "type": "string",
      "description": "要执行的 shell 命令（如 ls -la, cat file.txt, git status）"
    },
    "terminal_id": {
      "type": "string",
      "description": "可选。要复用的终端 id。首次调用不传，工具会创建新终端并返回 id。后续调用传入此 id 可复用同一终端（保留工作目录、env、shell 历史）。如果该终端已被用户关闭，调用会返回错误，此时需不传 terminal_id 重新创建。"
    }
  },
  "required": ["command"]
}
''';

  // 1. 在 Rust 后端注册工具元信息
  LlmService().registerFrontendTool(
    name: toolName,
    description: description,
    parameters: parameters,
  );

  // 2. 在 EngineClient 注册 handler
  EngineClient.instance.registerToolHandler(toolName, _handleSimulatedTerminal);
}

/// 注册 `terminal_send_input` 工具。
///
/// 工具 schema：
/// ```json
/// {
///   "type": "object",
///   "properties": {
///     "terminal_id": { "type": "string", "description": "要发送输入的终端 id" },
///     "text": { "type": "string", "description": "要发送的原始输入文本" },
///     "press_enter": { "type": "boolean", "description": "可选，是否在 text 后追加回车" }
///   },
///   "required": ["terminal_id", "text"]
/// }
/// ```
///
/// 行为：向指定终端发送原始输入（不经过命令执行等待，直接写入 PTY），
/// 适用于回答交互式提示（如 y/n 确认、vi 命令、进度输入）等场景。
void registerTerminalSendInput() {
  const toolName = 'terminal_send_input';
  const description =
      '向指定终端发送原始输入（默认不自动追加换行）。'
      '适用于回答交互式提示（如确认 y/n、vi 命令、输入密码等）的场景。'
      '需要先通过 simulated_terminal 工具创建终端并获取 terminal_id，'
      '或复用 simulated_terminal 返回的 terminal_id。'
      '如果终端已被用户关闭，调用会失败，需重新调用 simulated_terminal 创建。';
  const parameters = r'''
{
  "type": "object",
  "properties": {
    "terminal_id": {
      "type": "string",
      "description": "要发送输入的终端 id，来自 simulated_terminal 的返回。如果该终端已被用户关闭，调用会失败，需重新调用 simulated_terminal 创建新终端。"
    },
    "text": {
      "type": "string",
      "description": "要发送的原始输入文本，不会自动追加换行"
    },
    "press_enter": {
      "type": "boolean",
      "description": "可选，默认 false。为 true 时在 text 后追加回车（\\n），可用于确认提示"
    }
  },
  "required": ["terminal_id", "text"]
}
''';

  // 1. 在 Rust 后端注册工具元信息
  LlmService().registerFrontendTool(
    name: toolName,
    description: description,
    parameters: parameters,
  );

  // 2. 在 EngineClient 注册 handler
  EngineClient.instance.registerToolHandler(toolName, _handleTerminalSendInput);
}

/// `terminal_send_input` 工具的执行 handler。
///
/// 复用规则：
/// - 必须传 `terminal_id`（由 `simulated_terminal` 创建/返回）
/// - 传的 id 不存在或已关闭 → 返回错误，提示重新创建终端
Future<String> _handleTerminalSendInput(
  EngineEvent_FrontendToolCall event,
) async {
  // 1. 解析入参
  final args = event.arguments.isEmpty
      ? <String, dynamic>{}
      : (jsonDecode(event.arguments) as Map<String, dynamic>);

  final terminalId = args['terminal_id']?.toString();
  final text = args['text']?.toString() ?? '';
  final pressEnter = args['press_enter'] == true;

  if (terminalId == null || terminalId.isEmpty) {
    return 'Error: missing "terminal_id" parameter. '
        'Call simulated_terminal first to create a terminal and get its id.';
  }
  if (text.isEmpty && !pressEnter) {
    return 'Error: missing or empty "text" parameter';
  }

  // 2. 检查终端是否存在
  if (!XtermStore.instance.hasTab(terminalId)) {
    return 'Error: Terminal "$terminalId" has been closed by the user. '
        'Call simulated_terminal WITHOUT terminal_id to create a new terminal.';
  }

  // 3. 确保 PTY 已启动并发送输入
  final session = XtermStore.instance.forId(terminalId);
  session.ensurePtyStarted(shell: resolveShell());
  session.sendInput(pressEnter ? '$text\n' : text);

  return '[terminal_id: $terminalId]\nInput sent.';
}

/// `simulated_terminal` 工具的执行 handler。
///
/// 复用规则：
/// - 不传 `terminal_id` → 创建新终端（生成 nanoid），返回 id + 输出
/// - 传 `terminal_id` 且 tab 存在 → 复用，返回输出
/// - 传 `terminal_id` 但 tab 已关闭 → 返回错误，提示重新创建
Future<String> _handleSimulatedTerminal(
  EngineEvent_FrontendToolCall event,
) async {
  // 1. 解析入参
  final args = event.arguments.isEmpty
      ? <String, dynamic>{}
      : (jsonDecode(event.arguments) as Map<String, dynamic>);

  final command = args['command']?.toString();
  if (command == null || command.isEmpty) {
    return 'Error: missing or empty "command" parameter';
  }

  final terminalId = args['terminal_id']?.toString();
  final shell = resolveShell();

  // 2. 确定 tabId：传入则复用，不传则新建
  String tabId;
  bool isCreated = false;

  if (terminalId != null && terminalId.isNotEmpty) {
    // 复用模式：检查 tab 是否存在
    if (!XtermStore.instance.hasTab(terminalId)) {
      return 'Error: Terminal "$terminalId" has been closed by the user. '
          'Call this tool again WITHOUT the terminal_id parameter to create a new terminal.';
    }
    tabId = terminalId;
  } else {
    // 创建模式：生成新 id
    tabId = 'term_${nanoid(8)}';
    isCreated = true;
  }

  // 3. 打开/复用 tab（openTab 会自动展开面板 + 激活 tab + 确保 session 存在）
  XtermStore.instance.openTab(tabId, shell: shell);

  // 4. 获取底层 session 并确保 PTY 已启动
  final session = XtermStore.instance.forId(tabId);
  session.ensurePtyStarted(shell: shell);

  // 5. 执行命令（CommandRunner 会等待 shell 集成的 OSC 633;D 结束标记）
  try {
    final output = await session.execute(
      command,
      timeout: const Duration(seconds: 60),
    );

    // 6. 组装返回内容：包含 terminal_id 供 AI 下次复用
    final prefix = isCreated
        ? '[Terminal created. terminal_id: $tabId]\n'
        : '[Terminal reused. terminal_id: $tabId]\n';

    final body = output.isEmpty ? '(命令执行完毕，无输出)' : output;
    return '$prefix$body';
  } catch (e) {
    return '[terminal_id: $tabId]\nError executing command: $e';
  }
}
