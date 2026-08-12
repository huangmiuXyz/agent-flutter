import 'dart:convert';

import 'package:fleather/fleather.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/chat/chat_fleather.dart';
import 'package:agent/rust_bridge/api/types.dart' as api;
import 'package:agent/services/image_store.dart';
import 'package:agent/services/session/part_types.dart';
import 'package:agent/store/theme_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/text/app_text.dart';

import 'chat_expandable_part.dart';
import 'chat_image_part.dart';
import 'chat_search_part.dart';

import '../custom_tools_render/chat_diff_block.dart';
import 'chat_text_part.dart';
import 'package:agent/widgets/terminal/readonly_terminal.dart';

/// 用户消息编辑重试回调
///
/// [msgId] 要重试的消息 ID，[newContent] 编辑后的文本（含 `[图片N]` 引用标记），
/// [imagePaths] 编辑后的图片附件（绝对路径，按文档顺序），
/// [imageNames] 与 [imagePaths] 一一对应的原始文件名。
typedef OnRetryMessage =
    void Function(
      String msgId,
      String newContent,
      List<String> imagePaths,
      List<String> imageNames,
    );

/// 用户消息卡片点击标记 — 与 `ChatContent` 外层「点击空白取消焦点」协作。
///
/// pointer 事件按 hit test 路径**叶子→根**分发：卡片内层 `Listener` 在
/// `onPointerUp` 置位（先执行），`ChatContent` 外层读取后消费（后执行），
/// 从而点击用户消息卡片的**任何位置**（含空白/间距/按钮）都不触发 unfocus；
/// 外层 `onPointerDown` 每次重置，保证点击卡片外的空白仍正常取消焦点。
bool userMessagePointerUp = false;

/// 用户消息 — 基于 Fleather 的可编辑富文本消息，图片以 `[图片N]` 标签内嵌，
/// 支持增删图片，回车重试。
class _UserMessage extends HookWidget {
  final String sessionId;
  final String msgId;
  final List<api.PartInfo> visibleParts;
  final CustomTheme custom;
  final double minPartHeight;
  final OnRetryMessage? onRetry;
  final ValueChanged<bool>? onFocusChanged;

  const _UserMessage({
    required this.sessionId,
    required this.msgId,
    required this.visibleParts,
    required this.custom,
    required this.minPartHeight,
    this.onRetry,
    this.onFocusChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 找到第一个 text part 的内容作为初始值
    final textPart = visibleParts.cast<api.PartInfo?>().firstWhere(
      (p) => p!.partType == PartTypes.text,
      orElse: () => null,
    );
    final initialText = textPart != null
        ? ChatTextPart.extractDisplayText(textPart.content)
        : '';
    final imageParts = visibleParts
        .where((p) => p.partType == PartTypes.image)
        .toList();
    // image part content 为 `{"file": 存储名, "name": 原始名}` JSON，
    // 兼容旧数据（content 直接是存储文件名）
    final storedNames = <String>[];
    final displayNames = <String>[];
    for (final part in imageParts) {
      final content = part.content;
      String stored = content;
      String display = '';
      try {
        final json = jsonDecode(content);
        if (json is Map<String, dynamic>) {
          stored = json['file'] as String? ?? content;
          display = json['name'] as String? ?? '';
        }
      } catch (_) {}
      storedNames.add(stored);
      displayNames.add(display.isEmpty ? stored : display);
    }
    final imagePaths = storedNames
        .map((n) => ImageStore.instance.resolvePath(n))
        .toList(growable: false);

    final controller = useMemoized(() => FleatherController());
    final focusNode = useFocusNode();
    // 图片按钮仅在编辑框聚焦时显示
    final isFocused = useState(false);

    // 文档内容变化（重试后 parts 更新）时重建文档
    final docKey =
        '$initialText|${storedNames.join(',')}|${displayNames.join(',')}';
    useEffect(() {
      controller.clear();
      controller.compose(
        buildUserMessageDelta(
          text: initialText,
          imagePaths: imagePaths,
          storedNames: storedNames,
          displayNames: displayNames,
          // clear() 后文档已含结尾换行，不再追加，避免多出一个空行
          trailingNewline: false,
        ),
        source: ChangeSource.local,
      );
      return null;
    }, [docKey]);

    useEffect(() {
      void onFocus() {
        isFocused.value = focusNode.hasFocus;
        onFocusChanged?.call(focusNode.hasFocus);
      }

      focusNode.addListener(onFocus);
      return () => focusNode.removeListener(onFocus);
    }, [focusNode, onFocusChanged]);

    void handleSubmit() {
      final compose = extractChatCompose(controller);
      final newText = compose.text.replaceAll('\n', '').trim();
      if (newText.isEmpty && compose.imagePaths.isEmpty) return;
      focusNode.unfocus();
      onRetry?.call(msgId, newText, compose.imagePaths, compose.imageNames);
    }

    /// 添加图片：复制到 File 目录后插入标签
    Future<void> pickImages() async {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (result == null || result.files.isEmpty) return;
      for (final file in result.files) {
        final src = file.path;
        if (src == null) continue;
        try {
          final img = await ImageStore.instance.importImage(src);
          insertImageTag(
            controller,
            img.path,
            img.storedName,
            displayName: img.displayName,
          );
        } catch (_) {
          // 复制失败跳过该图片，不影响其余图片
        }
      }
      focusNode.requestFocus();
    }

    // 垂直方向与其他 part 一致用 xs：相邻项各贡献 xs，视觉 8px
    final messagePadding = EdgeInsets.symmetric(
      horizontal: custom.spacing.md,
      vertical: custom.spacing.xs,
    );

    // 整张卡片（含空白/间距/按钮）点击都不触发外层「点击空白取消焦点」：
    // pointer up 置位标记，外层 ChatContent 读取后消费（见 userMessagePointerUp）
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: (_) => userMessagePointerUp = true,
      child: Padding(
        padding: messagePadding,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: custom.colors.cardBackground,
            borderRadius: custom.radii.sm,
            border: Border.all(color: custom.colors.cardBorder, width: 1),
            boxShadow: custom.shadows.small,
          ),
          padding: EdgeInsets.all(custom.spacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 20),
                child: ChatFleather(
                  controller: controller,
                  focusNode: focusNode,
                  onSubmit: handleSubmit,
                  // 消息编辑：按内容自适应高度，不占满父级
                  expands: false,
                  // 紧凑：去掉段落上下间距，贴近原 TextField 高度
                  compact: true,
                  // 行高由字体自然决定，保证单行文本垂直居中（不强制 strut 行高）
                  strutStyle: StrutStyle(fontSize: custom.typography.bodySize),
                  // 编辑消息不显示输入框占位文案
                  placeholder: null,
                ),
              ),
              SizedBox(height: custom.spacing.xs),
              // 仅聚焦时显示图片按钮，避免干扰消息浏览
              if (isFocused.value)
                Row(
                  children: [
                    AppIconButton(
                      icon: 'image',
                      size: ButtonSize.sm,
                      backgroundColor: custom.colors.hover,
                      tooltip: '添加图片',
                      onPressed: pickImages,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单条消息的渲染组件
///
/// 接收 [parts] 直接渲染，流式内容由父级通过更新 parts 实现。
///
/// 用户消息支持点击编辑，回车重试。
class ChatMessageItem extends HookWidget {
  final String sessionId;
  final String msgId;
  final String role;
  final List<api.PartInfo> parts;

  /// 模型名称（仅第一条 assistant 消息有值，其余为 null）
  final String? modelName;

  /// 用户消息编辑重试回调
  final OnRetryMessage? onRetry;

  /// 后续消息被聚焦编辑时，本消息变灰提示将被删除
  final bool dimmed;

  /// 焦点变化回调
  final ValueChanged<bool>? onFocusChanged;

  /// 当前会话是否处于流式输出中（传递给 ChatTextPart 用于增量追加）
  final bool streaming;

  /// part_id → 工具流式输出累积文本（ToolOutputDelta 事件实时追加，
  /// 仅执行中的工具调用卡片使用只读终端展示）
  final Map<String, String> toolStreamedOutputs;

  const ChatMessageItem({
    super.key,
    required this.sessionId,
    required this.msgId,
    required this.role,
    required this.parts,
    this.modelName,
    this.onRetry,
    this.dimmed = false,
    this.onFocusChanged,
    this.streaming = false,
    this.toolStreamedOutputs = const {},
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    // parts 列表本身即是时间顺序：流式按事件到达追加，重载按 DB 行序（rowid）
    // 返回。不要按 seq 排序 —— 预创建部件（text）的 seq 固定为 1，而搜索/
    // 工具卡片发生在回答之前，seq 会把它俩错排到答案后面。
    final visibleParts = parts.where((p) => _isVisiblePart(p)).toList();

    if (visibleParts.isEmpty) {
      return const SizedBox.shrink();
    }

    // ── part widget 实例缓存 ──
    // 流式输出中每帧都会重建本条消息；parts 列表是同一个 List 实例，
    // 只有内容变化的 part 会被 copyWith 替换为新实例。因此按 part 实例
    // identity 缓存已构建的 widget：未变化的 part 返回相同 widget 实例，
    // Flutter updateChild 对相同实例直接跳过子树重建 —— 工具调用卡片等
    // 大批量 part 在流式期间不再每帧重复解析/构建（曾导致严重卡顿）。
    // 缓存键 = (part 实例, 是否最后一项, streaming)：间距（底部 padding）
    // 随位置变化；streaming 在 Done/Error 后翻转（part 实例不变），
    // 必须纳入键，否则文本 part 会停留在流式增量渲染态（最后一行
    // 永远以纯文本显示，代码围栏不再闭合）。
    final partCache = useRef<Map<Object, Widget>>({});
    // 主题切换时缓存失效（缓存树内引用的是旧主题样式）
    final cacheTheme = useRef<CustomTheme?>(null);
    if (!identical(cacheTheme.value, custom)) {
      cacheTheme.value = custom;
      partCache.value.clear();
    }
    // streaming 翻转时整体失效：文本 part 的渲染模式随 streaming 切换，
    // 旧态条目（part 实例未变）永远不会被命中，只占内存
    final cacheStreaming = useRef<bool>(false);
    if (cacheStreaming.value != streaming) {
      cacheStreaming.value = streaming;
      partCache.value.clear();
    }
    // 工具流式输出变化时工具卡片必须重建（part 实例未变但终端内容在增长）
    final cacheStreamed = useRef<Map<String, String>>({});
    if (cacheStreamed.value != toolStreamedOutputs) {
      cacheStreamed.value = toolStreamedOutputs;
      partCache.value.clear();
    }
    // Markdown 字体切换时聊天文本 part 必须重建（ChatTextPart 内部监听
    // markdownFontFamily，但外层 partCache 缓存了 widget 实例）
    final markdownFont = useExistingSignal(
      ThemeStore.instance.markdownFontFamily,
    );
    final cacheMarkdownFont = useRef<String?>(null);
    if (cacheMarkdownFont.value != markdownFont.value) {
      cacheMarkdownFont.value = markdownFont.value;
      partCache.value.clear();
    }

    final minPartHeight = custom.controls.chatPartCollapsedHeight;

    // 用户消息：支持点击编辑。
    // 子智能体插入的结果（sub_agent_text）除外——它是系统插入的只读卡片，
    // 走下方普通 part 渲染（「子智能体插入」样式），不显示为可编辑输入框。
    final hasSubAgentPart = visibleParts.any(
      (p) => p.partType == PartTypes.subAgentText,
    );
    if (role == 'user' && !hasSubAgentPart) {
      return _UserMessage(
        sessionId: sessionId,
        msgId: msgId,
        visibleParts: visibleParts,
        custom: custom,
        minPartHeight: minPartHeight,
        onRetry: onRetry,
        onFocusChanged: onFocusChanged,
      );
    }

    // 模型标签（仅第一条 assistant 消息显示）
    // 与第一个 part 在同一 item 内（共享同一份 messagePadding），
    // 间距完全由 bottom 直接贡献：sm(8) 才能与普通 part 间距 8px 一致
    final modelBadge = modelName != null && role == 'assistant'
        ? Padding(
            padding: EdgeInsets.only(bottom: custom.spacing.sm),
            child: AppText(
              modelName!,
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
            ),
          )
        : null;

    // 完全按 parts 原始顺序渲染：不做任何合并/拆分/移动，
    // 每个 part 按自身类型显示（思考、搜索、答案各归其位）。
    final partsWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ?modelBadge,
        for (int i = 0; i < visibleParts.length; i++)
          _buildPartWithSpacing(
            i,
            visibleParts,
            custom,
            minPartHeight,
            partCache.value,
          ),
      ],
    );

    final messagePadding = EdgeInsets.symmetric(
      horizontal: custom.spacing.md,
      vertical: custom.spacing.xs,
    );

    Widget result = Padding(padding: messagePadding, child: partsWidget);
    if (dimmed) {
      result = Opacity(opacity: 0.35, child: result);
    }
    return result;
  }

  bool _isVisiblePart(api.PartInfo part) {
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

  Widget _buildPartWithSpacing(
    int index,
    List<api.PartInfo> visibleParts,
    CustomTheme custom,
    double minPartHeight,
    Map<Object, Widget> partCache,
  ) {
    final part = visibleParts[index];
    final isLast = index == visibleParts.length - 1;
    // 缓存查找：part 实例与位置未变 → 复用整个（含薄壳的）widget 实例，
    // 子树完全不 rebuild；RepaintBoundary 同时隔离未变化卡片的重绘。
    // 流式输出文本纳入键：工具卡片内容增长时缓存失效重建。
    return partCache.putIfAbsent(
      (part, isLast, streaming, toolStreamedOutputs[part.id]),
      () => _buildPartWithSpacingInner(
        part,
        custom,
        minPartHeight,
        isLast,
        toolStreamedOutputs[part.id],
      ),
    );
  }

  Widget _buildPartWithSpacingInner(
    api.PartInfo part,
    CustomTheme custom,
    double minPartHeight,
    bool isLast,
    String? streamedText,
  ) {
    final widget = _buildPart(part, custom, streamedText);
    final constrained = Container(
      constraints: BoxConstraints(minHeight: minPartHeight),
      alignment: Alignment.centerLeft,
      child: widget,
    );
    // 重绘隔离：part 未变化时跳过 paint，大幅降低重绘成本
    final isolated = RepaintBoundary(child: constrained);
    if (!isLast) {
      return Padding(
        padding: EdgeInsets.only(bottom: custom.spacing.sm),
        child: isolated,
      );
    }
    return isolated;
  }

  Widget _buildPart(
    api.PartInfo part,
    CustomTheme custom,
    String? streamedText,
  ) {
    return switch (part.partType) {
      PartTypes.text => ChatTextPart(
        content: part.content,
        streaming: streaming,
      ),
      PartTypes.reasoning => ChatExpandablePart(
        content: part.content,
        iconName: 'lightbulb',
        title: '深度思考',
        titleColor: custom.colors.textSecondary,
        // 流式思考内容增长时自动滚动到底部
        stickToBottom: true,
      ),
      PartTypes.image => ChatImagePart(content: part.content),
      PartTypes.toolCall ||
      PartTypes.toolCallFrag => _buildToolCallPart(part, custom, streamedText),
      PartTypes.toolResult => const SizedBox.shrink(),
      PartTypes.webSearch => ChatSearchPart(content: part.content),
      PartTypes.subAgentText => _buildSubAgentPart(part, custom),
      _ => const SizedBox.shrink(),
    };
  }

  /// 子智能体插入的结果：卡片样式（来源标签 + 正文）
  Widget _buildSubAgentPart(api.PartInfo part, CustomTheme custom) {
    return Container(
      padding: EdgeInsets.all(custom.spacing.md),
      decoration: BoxDecoration(
        color: custom.colors.cardBackground,
        borderRadius: custom.radii.md,
        border: Border.all(color: custom.colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_tree_outlined,
                size: 14,
                color: custom.colors.accent,
              ),
              const SizedBox(width: 4),
              AppText(
                '子智能体插入',
                variant: AppTextVariant.caption,
                color: custom.colors.accent,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ChatTextPart(content: part.content, streaming: false),
        ],
      ),
    );
  }

  /// 读取工具调用结果：内嵌在 part 内容里的 `tool_result` 字段（完成时由 Rust 写入）。
  String? _lookupResult(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      final inlineResult = json['tool_result'] as String?;
      if (inlineResult != null && inlineResult.isNotEmpty) {
        return inlineResult;
      }
    } catch (_) {}
    return null;
  }

  /// 工具调用卡片：apply_patch 走专用 diff 渲染，其余保持通用样式。
  ///
  /// 执行中的 shell_command 等工具（tool_call_frag 态）如有流式输出，
  /// 在展开区渲染只读终端实时展示；命令结束后（tool_call 态）由
  /// resultContent 展示最终结果，终端隐藏（与历史重载渲染一致）。
  Widget _buildToolCallPart(
    api.PartInfo part,
    CustomTheme custom,
    String? streamedText,
  ) {
    final isPatch = _toolCallName(part.content) == 'apply_patch';
    // 仅执行中的卡片展示流式终端；完成后 toolOutputBuffers 仍在会话内
    // 保留，但不再渲染（结果以 tool_result 文本为准）
    final isRunning = part.partType == PartTypes.toolCallFrag;
    final streamed =
        isRunning && streamedText != null && streamedText.isNotEmpty
        ? streamedText
        : null;
    return ChatExpandablePart(
      content: part.content,
      iconName: isPatch ? 'fileCode' : 'mousePointer2',
      title: isPatch ? '应用补丁' : _toolCallTitle(part.content),
      titleColor: isPatch ? custom.colors.success : custom.colors.accent,
      resultContent: _lookupResult(part.content),
      argumentsBuilder: isPatch ? _buildPatchDiff : null,
      // 工具调用去掉左侧分割线（深度思考保留）
      showLeftDivider: false,
      // 仅 apply_patch 默认展开便于直接查看 diff，其余工具调用保持收起；
      // 有流式输出时默认展开（用户能看到执行过程）
      initiallyExpanded: isPatch || streamed != null,
      // 流式输出：只读终端（xterm）实时展示，支持 ANSI/进度条/滚动
      children: [if (streamed != null) ReadonlyTerminalView(text: streamed)],
    );
  }

  /// 用 diff 代码块渲染 apply_patch 的 patch 参数。
  /// 提取逻辑在 ChatDiffBlock 内部增量完成：流式期间 arguments 是
  /// 不断增长的半截 JSON（`{"patch": "*** Begin Patch...`），整段
  /// jsonDecode 必然失败；若等 JSON 完整才渲染，diff 只能在流式结束后
  /// 一次性出现（非实时）。StreamingPatchExtractor 容错提取 patch
  /// 字符串值（字符串未闭合时取全部剩余文本、转义逐字符解码），
  /// diff 随流式逐行增长，每 chunk 只处理新增文本。
  Widget _buildPatchDiff(BuildContext context, String rawArguments) {
    return ChatDiffBlock.arguments(rawArguments: rawArguments);
  }

  /// 读取工具调用名称（streaming 早期即稳定）
  String _toolCallName(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      final function = json['function'] as Map<String, dynamic>?;
      final name = function?['name'] as String?;
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return '';
  }

  String _toolCallTitle(String content) {
    final name = _toolCallName(content);
    if (name.isNotEmpty) return '工具调用: $name';
    return '工具调用';
  }
}
