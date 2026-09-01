/// 单个会话的内存状态模型
library;

import 'package:agent/rust_bridge/api/types.dart' as api;

import 'part_types.dart';

/// 等待用户确认的工具调用（Zed 式内联确认：卡片上显示三个按钮）。
class PendingToolPermission {
  const PendingToolPermission({
    required this.callId,
    required this.toolName,
    required this.arguments,
  });

  /// 回传决定用的唯一调用标识（来自 ToolPermissionRequest 事件）
  final String callId;

  /// 待确认的工具名
  final String toolName;

  /// 工具入参（JSON 字符串，供展示）
  final String arguments;
}

class SessionState {
  final String sessionId;

  /// 按 msg_id 分组的 parts
  ///
  /// 写入请统一走 [addPart] / [setMessageParts] / [removeMessage] / [updatePart] /
  /// [ensureMessage]，它们会同步维护 [_partIndex]；直接改动 list 会让索引失效。
  final Map<String, List<api.PartInfo>> partsByMsg = {};

  /// part_id → 所在位置（msg_id + 组内下标）。
  /// 流式期间每个 chunk 都要按 part_id 定位，全表扫描在长会话下是 O(总 part 数)。
  final Map<String, _PartRef> _partIndex = {};

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

  /// part_id → 等待用户确认的工具调用（ToolPermissionRequest 事件写入，
  /// 用户点击按钮或工具结果到达后移除）
  final Map<String, PendingToolPermission> pendingPermissions = {};

  /// msg_id → role（"user", "assistant", "tool" 等）
  final Map<String, String> messageRoles = {};

  /// msg_id → 模型名（仅 assistant 消息有值）
  final Map<String, String> messageModels = {};

  /// 自动重试提示文本（Retry 事件写入，首个内容/流结束/出错后清除）。
  /// 非空时消息列表底部显示系统提示行。
  String? retryStatus;

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
    _partIndex.clear();
    messageOrder.clear();
    partLens.clear();
    // 重试提示仅在当次会话内有效（历史重载无此状态）
    retryStatus = null;
    // 流式输出缓冲仅在当次会话内有效（历史重载无增量数据，
    // 渲染端会回退到 tool_result 一次性回放）
    toolOutputBuffers.clear();
    toolOutputLens.clear();
    // 权限确认同样只在当次会话内有效
    pendingPermissions.clear();

    // messageOrder.contains 是 O(N)，在循环里是 O(N²)；用局部 set 去重
    final seen = <String>{};
    for (final part in parts) {
      addPart(part.msgId, part);
      if (seen.add(part.msgId)) {
        messageOrder.add(part.msgId);
      }
      if (part.partType == PartTypes.text) {
        partLens[part.id] = part.content.length;
      } else if (part.partType == PartTypes.reasoning) {
        reasoningPartLens[part.id] = part.content.length;
      }
    }
  }

  // ── parts 读写（统一入口，维护 _partIndex）──

  /// 追加一个 part 到 msgId 对应的消息
  void addPart(String msgId, api.PartInfo part) {
    final list = partsByMsg.putIfAbsent(msgId, () => <api.PartInfo>[]);
    _partIndex[part.id] = _PartRef(msgId, list.length);
    list.add(part);
  }

  /// 重置 msgId 对应的 parts（新建/覆盖消息内容时用）
  void setMessageParts(String msgId, List<api.PartInfo> parts) {
    removeMessage(msgId);
    partsByMsg[msgId] = parts;
    for (var i = 0; i < parts.length; i++) {
      _partIndex[parts[i].id] = _PartRef(msgId, i);
    }
  }

  /// 删除整条消息，返回被删除的 parts
  List<api.PartInfo>? removeMessage(String msgId) {
    final removed = partsByMsg.remove(msgId);
    if (removed == null) return null;
    for (final part in removed) {
      _partIndex.remove(part.id);
    }
    return removed;
  }

  /// 确保 msgId 对应的消息存在（不存在则按当前顺序追加）
  void ensureMessage(String msgId) {
    if (partsByMsg.containsKey(msgId)) return;
    partsByMsg[msgId] = <api.PartInfo>[];
    if (!messageOrder.contains(msgId)) {
      messageOrder.add(msgId);
    }
  }

  /// msgId 下已有的 part 数量
  int partCountOf(String msgId) => partsByMsg[msgId]?.length ?? 0;

  /// 按 part_id 取 part（O(1)）
  api.PartInfo? partById(String partId) {
    final ref = _partIndex[partId];
    if (ref == null) return null;
    final list = partsByMsg[ref.msgId];
    if (list == null || ref.index >= list.length) return null;
    return list[ref.index];
  }

  /// 原地更新 part 的 content / partType（未传的字段保持不变）
  void updatePart(String partId, {String? content, String? partType}) {
    final ref = _partIndex[partId];
    if (ref == null) return;
    final list = partsByMsg[ref.msgId];
    if (list == null || ref.index >= list.length) return;
    var updated = list[ref.index];
    if (content != null) updated = updated.copyWith(content: content);
    if (partType != null) updated = updated.copyWith(partType: partType);
    list[ref.index] = updated;
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
    updatePart(partId, content: content);
  }

  /// 更新 part 的类型（如 tool_call_frag → tool_call，内容原地覆盖）
  void updatePartType(String partId, String partType) {
    updatePart(partId, partType: partType);
  }
}

/// part 在 [SessionState.partsByMsg] 中的位置
class _PartRef {
  const _PartRef(this.msgId, this.index);

  final String msgId;
  final int index;
}
