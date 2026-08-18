/// 消息拍平 + 锚点数据收集 + 估算高度 — 纯函数，无 UI 依赖，可单测。
library;

import 'package:agent/features/chat/widgets/chat_text_part.dart';
import 'package:agent/features/chat/widgets/message_anchors_panel.dart';
import 'package:agent/rust_bridge/api/types.dart' as api;
import 'package:agent/services/session/part_types.dart';

/// 拍平列表 item：用户消息整条 / assistant 单个 part。
/// 全部消息按此拍平后，消息列表只在视口内构建 item（列表级虚拟化）。
sealed class FlatItem {
  const FlatItem();
}

/// 整条消息一个 item（用户消息：编辑卡片需要全部 parts 一起渲染）
final class FlatMessageItem extends FlatItem {
  const FlatMessageItem(this.msgIndex);

  final int msgIndex;
}

/// assistant 消息的单个 part
final class FlatPartItem extends FlatItem {
  const FlatPartItem(this.msgIndex, this.partIndex);

  final int msgIndex;
  final int partIndex;
}

/// 拍平结果：items 供列表渲染，anchors 供锚点面板，estTotalHeight
/// 供滚底测量区初始跳转，itemCount 含独立流式指示器占位。
class FlattenResult {
  const FlattenResult({
    required this.items,
    required this.anchors,
    required this.estTotalHeight,
    required this.itemCount,
  });

  final List<FlatItem> items;
  final List<UserAnchorData> anchors;
  final double estTotalHeight;
  final int itemCount;
}

/// 用户消息估算高度（锚点比例用，未测量区域按此累计；点击跳转有
/// 离屏测量兜底，估算值只影响锚点概览位置，不需要精确）
const double estUserMsgHeight = 64;
const double estToolCardHeight = 88;
const double estImageHeight = 240;
const double estSearchHeight = 96;
const double estReasoningHeight = 56;

/// 估算高度：阅读宽度约半屏，正文 14px 行高约 28px（含段间距），
/// 每行约 56 个中文字符；markdown 段落间距一并计入，避免锚点
/// 比例整体偏低（历史经验：行高 24 / 每行 70 字低估约 40%）
const double estTextCharsPerLine = 56;
const double estTextLineHeight = 28;

double estTextHeight(String content) {
  final lines = (content.length / estTextCharsPerLine).ceil();
  return lines * estTextLineHeight + 16;
}

/// 单个 part 的估算高度（锚点概览用）
double estPartHeight(api.PartInfo part) {
  return switch (part.partType) {
    PartTypes.text => estTextHeight(part.content),
    PartTypes.reasoning => estReasoningHeight,
    PartTypes.toolCall || PartTypes.toolCallFrag => estToolCardHeight,
    PartTypes.image => estImageHeight,
    PartTypes.webSearch => estSearchHeight,
    PartTypes.subAgentText => estTextHeight(part.content),
    _ => 48,
  };
}

/// 用户消息预览文本（锚点面板浮层显示）
String userMsgPreview(List<api.PartInfo> parts) {
  // 用户消息 content 存 JSON 包裹格式 `{"content":"..."}`（后端存储
  // 格式，消息正文显示时也经 ChatTextPart.extractDisplayText 解包），
  // 预览必须同样解包，否则浮层会显示 JSON 原文
  final text = parts
      .where((p) => p.partType == PartTypes.text)
      .map((p) => ChatTextPart.extractDisplayText(p.content).trim())
      .where((s) => s.isNotEmpty)
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (text.isNotEmpty) return text;
  if (parts.any((p) => p.partType == PartTypes.image)) return '[图片]';
  return '(空消息)';
}

/// part 是否在消息列表中占位（纯工具/空内容不渲染）
bool isPartVisible(api.PartInfo part) {
  if (part.partType == PartTypes.toolResult) return false;
  // 工具返回的图片消息：仅模型上下文可见，前端不渲染
  if (part.partType == PartTypes.toolImage) return false;
  if (part.partType == PartTypes.text) {
    return part.content.isNotEmpty;
  }
  if (part.partType == PartTypes.reasoning) {
    return part.content.isNotEmpty;
  }
  if (part.partType == PartTypes.webSearch) {
    return part.content.isNotEmpty;
  }
  if (part.partType == PartTypes.subAgentText) {
    return part.content.isNotEmpty;
  }
  if (part.partType == PartTypes.image) {
    return part.content.isNotEmpty;
  }
  // tool_call / tool_call_frag 是同一个调用生命周期内的两种状态，都展示
  return part.partType == PartTypes.toolCall ||
      part.partType == PartTypes.toolCallFrag;
}

/// 拍平全部消息 + 收集用户消息锚点 + 累计估算高度游标。
///
/// [measuredOffsets]：msgId → 精确内容偏移（浏览过/测量过的缓存）。
/// 未测量区域按估算累计，已测量（缓存命中）的消息校准游标，
/// 让后续估算更准。纯函数，便于单测。
FlattenResult flattenMessageList({
  required List<String> messageOrder,
  required Map<String, List<api.PartInfo>> partsByMsg,
  required Map<String, String> messageRoles,
  required Map<String, double> measuredOffsets,
  required bool hasLatestTurn,
  required bool isStreaming,
  required int latestUserIndex,
  required bool hasRetryLine,
}) {
  final items = <FlatItem>[];
  final anchors = <UserAnchorData>[];
  var estCursor = 0.0;
  for (var m = 0; m < messageOrder.length; m++) {
    final msgId = messageOrder[m];
    final parts = partsByMsg[msgId] ?? [];
    // 纯工具类消息不占位
    if (parts.isNotEmpty && PartTypes.isToolOnly(parts)) continue;
    // 用户消息整条渲染（编辑/重试卡片）
    if (messageRoles[msgId] == 'user') {
      items.add(FlatMessageItem(m));
      final cached = measuredOffsets[msgId];
      final offset = cached ?? estCursor;
      anchors.add(
        UserAnchorData(
          msgId: msgId,
          preview: userMsgPreview(parts),
          offset: offset,
        ),
      );
      estCursor = offset + estUserMsgHeight;
      continue;
    }
    for (var p = 0; p < parts.length; p++) {
      final part = parts[p];
      // 不可见 part（toolResult/toolImage/空内容）不占位，
      // 避免渲染成 SizedBox.shrink 后仍留下 8px 幻影间距
      if (!isPartVisible(part)) continue;
      items.add(FlatPartItem(m, p));
      estCursor += estPartHeight(part);
    }
  }
  // 最新轮只有用户消息（无任何 assistant 内容）时，末尾显示独立 loading；
  // 有自动重试行时不再生成独立指示器占位（重试行已表达等待状态，且会
  // 被独立指示器推到下方，看起来像隔着一条助手信息）。
  final standaloneIndicator = !hasRetryLine &&
      hasLatestTurn &&
      isStreaming &&
      latestUserIndex == messageOrder.length - 1;
  return FlattenResult(
    items: items,
    anchors: anchors,
    estTotalHeight: estCursor,
    itemCount: items.length + (standaloneIndicator ? 1 : 0),
  );
}
