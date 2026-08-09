/// 单个会话的内存状态模型
library;

import 'package:agent/rust_bridge/api/types.dart' as api;

import 'part_types.dart';

class SessionState {
  final String sessionId;

  /// 按 msg_id 分组的 parts
  final Map<String, List<api.PartInfo>> partsByMsg = {};

  /// msg_id 的顺序列表
  final List<String> messageOrder = [];

  /// part_id → 已知内容长度（用于 total_len 去重）
  final Map<String, int> partLens = {};

  /// reasoning part_id → 已知内容长度（用于去重）
  final Map<String, int> reasoningPartLens = {};

  /// tool part_id → 流式输出累积文本（shell_command 等执行中的增量，
  /// 由 ToolOutputDelta 事件追加；命令结束后由 ToolCall 事件的结果覆盖）
  final Map<String, String> toolOutputBuffers = {};

  /// "partId|stream" → 已接收字节数（stdout/stderr 分别累计，用于去重）
  final Map<String, BigInt> toolOutputLens = {};

  /// msg_id → role（"user", "assistant", "tool" 等）
  final Map<String, String> messageRoles = {};

  /// msg_id → 模型名（仅 assistant 消息有值）
  final Map<String, String> messageModels = {};

  SessionState(this.sessionId);

  /// 从 DB 读取的消息角色加载
  void loadFromMessages(List<api.MessageInfo> messages) {
    messageRoles.clear();
    messageModels.clear();
    for (final msg in messages) {
      messageRoles[msg.id] = msg.role;
      if (msg.role == 'assistant' && msg.model.isNotEmpty) {
        final label = msg.provider.isNotEmpty
            ? '${msg.provider} / ${msg.model}'
            : msg.model;
        messageModels[msg.id] = label;
      }
    }
  }

  /// 从 DB 读取的 parts 加载状态
  void loadFromParts(List<api.PartInfo> parts) {
    partsByMsg.clear();
    messageOrder.clear();
    partLens.clear();
    // 流式输出缓冲仅在当次会话内有效（历史重载无增量数据，
    // 渲染端会回退到 tool_result 一次性回放）
    toolOutputBuffers.clear();
    toolOutputLens.clear();

    for (final part in parts) {
      partsByMsg.putIfAbsent(part.msgId, () => []).add(part);
      if (!messageOrder.contains(part.msgId)) {
        messageOrder.add(part.msgId);
      }
      if (part.partType == PartTypes.text) {
        partLens[part.id] = part.content.length;
      } else if (part.partType == PartTypes.reasoning) {
        reasoningPartLens[part.id] = part.content.length;
      }
    }
  }

  /// 通过 part_id + total_len 判断是否已有数据
  bool isTextRedundant(String partId, BigInt totalLen) {
    final known = partLens[partId] ?? 0;
    return totalLen.toInt() <= known;
  }

  void trackTextLength(String partId, BigInt totalLen) {
    partLens[partId] = totalLen.toInt();
  }

  /// 判断 reasoning part 是否冗余
  bool isReasoningRedundant(String partId, BigInt totalLen) {
    final known = reasoningPartLens[partId] ?? 0;
    return totalLen.toInt() <= known;
  }

  void trackReasoningLength(String partId, BigInt totalLen) {
    reasoningPartLens[partId] = totalLen.toInt();
  }

  /// 更新 part 的完整内容（用于 gap 修复后）
  void updatePartContent(String partId, String content) {
    for (final entry in partsByMsg.entries) {
      for (int i = 0; i < entry.value.length; i++) {
        if (entry.value[i].id == partId) {
          entry.value[i] = entry.value[i].copyWith(content: content);
          return;
        }
      }
    }
  }

  /// 更新 part 的类型（如 tool_call_frag → tool_call，内容原地覆盖）
  void updatePartType(String partId, String partType) {
    for (final entry in partsByMsg.entries) {
      for (int i = 0; i < entry.value.length; i++) {
        if (entry.value[i].id == partId) {
          entry.value[i] = entry.value[i].copyWith(partType: partType);
          return;
        }
      }
    }
  }
}
