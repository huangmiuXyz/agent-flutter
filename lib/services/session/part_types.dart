/// partType 常量与公共判断 — 避免魔法字符串散落各处。
///
/// `partType` 来自 Rust 端 `api.PartInfo.partType`，取值：
/// text / reasoning / tool_call / tool_call_frag / tool_result。
/// 统一在此定义，拼写错误可在编译期暴露，判断逻辑只维护一份。
library;

import 'package:agent/rust_bridge/api.dart' as api;

class PartTypes {
  PartTypes._();

  static const text = 'text';
  static const reasoning = 'reasoning';
  static const toolCall = 'tool_call';
  static const toolCallFrag = 'tool_call_frag';
  static const toolResult = 'tool_result';

  /// reasoning / tool_call / tool_call_frag 是否属于可展开 part。
  static bool isExpandable(String type) =>
      type == reasoning || type == toolCall || type == toolCallFrag;

  /// 消息是否只包含工具类 part（纯工具消息在消息列表中不占位）。
  static bool isToolOnly(List<api.PartInfo> parts) =>
      parts.every(
        (p) => p.partType == toolResult || p.partType == toolCallFrag,
      );
}

/// [api.PartInfo] 的便捷复制扩展（rust_bridge 生成类不便直接改）。
///
/// 当前仅需要修改 [api.PartInfo.content] 的场景（流式追加、重试编辑等）。
extension PartInfoX on api.PartInfo {
  api.PartInfo copyWith({String? content}) => api.PartInfo(
    id: id,
    msgId: msgId,
    seq: seq,
    partType: partType,
    content: content ?? this.content,
  );
}
