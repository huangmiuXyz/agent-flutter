/// partType 常量与公共判断 — 避免魔法字符串散落各处。
///
/// `partType` 来自 Rust 端 `api.PartInfo.partType`，取值：
/// text / reasoning / tool_call / tool_call_frag / tool_result。
/// 统一在此定义，拼写错误可在编译期暴露，判断逻辑只维护一份。
library;

import 'package:agent/rust_bridge/api/types.dart' as api;

class PartTypes {
  PartTypes._();

  static const text = 'text';
  static const reasoning = 'reasoning';
  static const toolCall = 'tool_call';
  static const toolCallFrag = 'tool_call_frag';
  static const toolResult = 'tool_result';
  /// 子智能体插入的结果消息（语义等同 text，仅渲染标记）
  static const subAgentText = 'sub_agent_text';

  /// 服务端联网搜索（web_search_call）— 仅展示，不本地执行
  /// web_search part 类型
  static const webSearch = 'web_search';

  /// 用户消息中的图片附件（content 为 `File/` 目录下的文件名）
  static const image = 'image';

  /// 消息是否只包含工具类 part（纯工具消息在消息列表中不占位）。
  static bool isToolOnly(List<api.PartInfo> parts) => parts.every(
    (p) => p.partType == toolResult || p.partType == toolCallFrag,
  );
}

/// [api.PartInfo] 的便捷复制扩展（rust_bridge 生成类不便直接改）。
///
/// 支持修改 [api.PartInfo.content]（流式追加、重试编辑等）与
/// [api.PartInfo.partType]（如 tool_call_frag → tool_call 原地覆盖）。
extension PartInfoX on api.PartInfo {
  api.PartInfo copyWith({String? content, String? partType}) => api.PartInfo(
    id: id,
    msgId: msgId,
    seq: seq,
    partType: partType ?? this.partType,
    content: content ?? this.content,
  );
}
