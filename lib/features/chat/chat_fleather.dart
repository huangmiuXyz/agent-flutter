import 'dart:io';

import 'package:fleather/fleather.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/theme/fleather_utils.dart';
import 'package:agent/utils/ime_composing_tracker.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 图片标签 embed 类型（Fleather 自定义 inline embed）。
///
/// embed 数据：`{_type: agent_image, _inline: true, path, filename, label}`，
/// label 形如「图片1」，用户在文本中引用（如「帮我参考[图片1]实现任务」），
/// 发送时文本中的标签会转为 `[图片N]` 标记、图片按文档顺序作为附件。
const kImageEmbedType = 'agent_image';

/// 统计文档中已有的图片标签数量（用于分配下一个标签编号）
int countImageTags(FleatherController controller) {
  var count = 0;
  for (final op in controller.document.toDelta().toList()) {
    final data = op.data;
    if (data is Map && data[EmbeddableObject.kTypeKey] == kImageEmbedType) {
      count++;
    }
  }
  return count;
}

/// 构造图片标签 embed 的 Map 数据
Map<String, dynamic> imageEmbedData({
  required String path,
  required String filename,
  required String label,
  String? displayName,
}) => {
  EmbeddableObject.kTypeKey: kImageEmbedType,
  EmbeddableObject.kInlineKey: true,
  'path': path,
  'filename': filename,
  'label': label,
  if (displayName != null && displayName.isNotEmpty) 'displayName': displayName,
};

/// 从用户消息内容构建编辑文档 delta。
///
/// - 文本中的 `[图片N]` 标记替换为对应顺序的图片标签 embed（位置一一对应）
/// - 未被文本引用的图片（如纯附件）追加在末尾
/// - [imagePaths]/[storedNames]/[displayNames] 按文档顺序一一对应
/// - [trailingNewline] 为 false 时不追加结尾换行（编辑框已含换行的场景，
///   避免多出一个空行）
Delta buildUserMessageDelta({
  required String text,
  required List<String> imagePaths,
  required List<String> storedNames,
  required List<String> displayNames,
  bool trailingNewline = true,
}) {
  final delta = Delta();
  final used = <int>{};
  // 仅匹配 `[图片N]` 编号引用（不用文件名匹配，避免同名/文本误匹配）
  final reg = RegExp(r'\[图片(\d+)\]');
  var cursor = 0;
  for (final m in reg.allMatches(text)) {
    if (m.start > cursor) {
      delta.insert(text.substring(cursor, m.start));
    }
    final idx = int.tryParse(m.group(1) ?? '');
    if (idx != null && idx >= 1 && idx <= imagePaths.length) {
      delta.insert(
        imageEmbedData(
          path: imagePaths[idx - 1],
          filename: storedNames[idx - 1],
          label: m.group(0)!.substring(1, m.group(0)!.length - 1),
          displayName: displayNames[idx - 1],
        ),
      );
      used.add(idx - 1);
    } else {
      // 引用编号超出图片数量（异常数据）：保留原文本
      delta.insert(m.group(0)!);
    }
    cursor = m.end;
  }
  if (cursor < text.length) {
    delta.insert(text.substring(cursor));
  }
  // 未被文本引用的图片追加在末尾
  for (int i = 0; i < imagePaths.length; i++) {
    if (used.contains(i)) continue;
    delta.insert(
      imageEmbedData(
        path: imagePaths[i],
        filename: storedNames[i],
        label: '图片${i + 1}',
        displayName: displayNames[i],
      ),
    );
  }
  if (trailingNewline) {
    delta.insert('\n');
  }
  return delta;
}

/// 在光标处插入图片标签 embed，返回分配的标签名（如「图片3」）。
///
/// [displayName] 为用户选择图片时的原始文件名（chip 显示/文本引用用）。
void insertImageTag(
  FleatherController controller,
  String path,
  String filename, {
  String? displayName,
}) {
  final label = '图片${countImageTags(controller) + 1}';
  final index = controller.selection.baseOffset;
  final change = Delta()
    ..retain(index)
    ..insert(
      imageEmbedData(
        path: path,
        filename: filename,
        label: label,
        displayName: displayName,
      ),
    );
  controller.compose(
    change,
    source: ChangeSource.local,
    // 光标移到标签之后，保证连续插入/输入按文档顺序排列
    selection: TextSelection.collapsed(offset: index + 1),
    forceUpdateSelection: true,
  );
}

/// 从 Fleather 文档提取发送内容。
///
/// 返回：
/// - [text]：纯文本，图片标签转为 `[图片N]` 编号标记（按文档顺序，
///   无歧义；不用文件名引用可避免同名图片/文本误匹配）
/// - [imagePaths]：按文档顺序的图片绝对路径（作为附件发送）
/// - [imageNames]：与 [imagePaths] 一一对应的原始文件名（DB 显示用）
({String text, List<String> imagePaths, List<String> imageNames})
extractChatCompose(FleatherController controller) {
  final buf = StringBuffer();
  final imagePaths = <String>[];
  final imageNames = <String>[];
  for (final op in controller.document.toDelta().toList()) {
    final data = op.data;
    if (data is String) {
      buf.write(data);
    } else if (data is Map) {
      if (data[EmbeddableObject.kTypeKey] == kImageEmbedType) {
        final label = data['label'];
        if (label is String && label.isNotEmpty) {
          buf.write('[$label]');
        }
        final path = data['path'];
        if (path is String && path.isNotEmpty) {
          imagePaths.add(path);
          imageNames.add(
            (data['displayName'] as String?)?.isNotEmpty == true
                ? data['displayName'] as String
                : (data['filename'] as String? ?? ''),
          );
        }
      }
    }
  }
  return (text: buf.toString(), imagePaths: imagePaths, imageNames: imageNames);
}

/// Scroll physics that completely eliminates any bounce/overscroll effect.
/// Overrides all relevant methods to ensure strict boundary clamping.
class _NoBounceScrollPhysics extends ScrollPhysics {
  const _NoBounceScrollPhysics({super.parent});

  @override
  _NoBounceScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _NoBounceScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Strict clamping: never allow going past boundaries
    if (value < position.minScrollExtent) {
      return value - position.minScrollExtent;
    }
    if (value > position.maxScrollExtent) {
      return value - position.maxScrollExtent;
    }
    return 0.0;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // No ballistic scrolling at all — stops immediately
    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}

class ChatFleather extends StatefulWidget {
  const ChatFleather({
    super.key,
    this.controller,
    this.focusNode,
    this.onSubmit,
    this.placeholder,
    this.expands = true,
    this.compact = false,
    this.strutStyle,
  });

  /// 外部传入的 controller，为空则内部自动创建
  final FleatherController? controller;

  /// 外部传入的 FocusNode（用于外部聚焦控制），为空则内部自动创建
  final FocusNode? focusNode;

  /// 按下 Enter 时回调（不含 Shift 修饰键）
  final VoidCallback? onSubmit;

  /// 空文档时显示的占位文本；为 null 时不显示
  final String? placeholder;

  /// 是否展开填充父级高度（消息编辑等无界高度场景传 false，按内容自适应）
  final bool expands;

  /// 紧凑模式：去掉文本块上下间距（消息编辑等紧凑场景）
  final bool compact;

  /// 自定义 strut 样式；为 null 时使用默认（forceStrutHeight 保证行高稳定）
  final StrutStyle? strutStyle;

  @override
  State<ChatFleather> createState() => _ChatFleatherState();
}

class _ChatFleatherState extends State<ChatFleather> {
  late FleatherController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? FleatherController();
    _controller.addListener(_onControllerChanged);
    // 外部传入的 FocusNode 由外部负责 dispose，内部创建的由自己 dispose
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    // 仅 dispose 内部创建的 controller；外部传入的由创建方负责
    // （ChatInput 在 useEffect cleanup 中 dispose），避免外部持有者
    // 在异步回调中继续使用已销毁的 controller。
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    // Rebuild to show/hide placeholder.
    setState(() {});
  }

  /// 文档是否为空：无文本且无图片标签
  bool get _isEmpty {
    for (final op in _controller.document.toDelta().toList()) {
      final data = op.data;
      if (data is String) {
        if (data.replaceAll('\n', '').isNotEmpty) return false;
      } else if (data is Map &&
          data[EmbeddableObject.kTypeKey] == kImageEmbedType) {
        return false;
      }
    }
    return true;
  }

  /// 处理 Enter：无修饰键时触发发送；
  /// 输入法组合中放行按键（不发送），让 IME 提交组合内容落下。
  /// 注意必须返回 ignored：若消费按键，Windows 引擎会跳过
  /// 键盘消息翻译链，组合内容无法提交。
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      // 带修饰键的 Enter（如 Shift+Enter 换行）不拦截
      return KeyEventResult.ignored;
    }
    if (ImeComposingTracker.instance.isComposing) {
      // 输入法组合中：不触发发送，把 Enter 留给 IME 提交组合内容
      return KeyEventResult.ignored;
    }
    widget.onSubmit?.call();
    return KeyEventResult.handled;
  }

  /// 图片标签 chip：小缩略图 + [图片N]，点击查看大图
  Widget _buildImageChip(BuildContext context, EmbedNode node) {
    final custom = CustomTheme.of(context);
    final data = node.value.data;
    final path = data['path'] as String? ?? '';
    // 优先显示原始文件名，缺失时回退为存储文件名
    final displayName = (data['displayName'] as String?)?.isNotEmpty == true
        ? data['displayName'] as String
        : (data['filename'] as String? ?? '');
    // Fleather 行内 embed 用 WidgetSpan 渲染（底部与文本 baseline 对齐）。
    // chip 总高必须等于文本行高（strut 1.3x）：占位与行高一致时
    // 光标、文本、chip 才在同一垂直体系内对齐。内部元素压缩居中。
    final lineHeight = custom.typography.bodySize * 1.3;
    // 高度 = 文本行高（占位与行一致，光标/文本/chip 对齐）；
    // 宽度由 chip 内容决定（固定宽度会在标签后留下空白）
    return SizedBox(
      height: lineHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: 1,
        heightFactor: 1,
        // 视觉微调：chip 在行内略偏上，向下移动 1px
        // （占位与行高一致，Transform 只影响绘制，光标位置不受影响）
        // Windows 文本基线位置与 macOS 不同（DirectWrite vs CoreText），
        // 同一偏移下 chip 在 Windows 视觉偏下，按平台区分偏移量。
        child: Transform.translate(
          offset: _imageChipOffset(),
          child: GestureDetector(
            onTap: () => _showImagePreview(context, path),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: custom.colors.hover,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: custom.colors.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (path.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.file(
                        File(path),
                        width: 14,
                        height: 14,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.image_outlined,
                          size: 14,
                          color: custom.colors.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(width: 3),
                  // 显示原始文件名（截断超长名）
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: AppText(
                      displayName.isEmpty ? '图片' : displayName,
                      variant: AppTextVariant.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      color: custom.colors.textPrimary,
                      style: const TextStyle(height: 1.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 平台相关的 chip 垂直偏移（仅影响绘制，不影响光标/布局）。
  ///
  /// macOS 保持原偏移；Windows 文本基线整体偏低，chip 视觉偏下，
  /// 需要上移补偿（数值按实际观感微调）。
  Offset _imageChipOffset() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return const Offset(0, -1);
      default:
        return const Offset(0, 1);
    }
  }

  void _showImagePreview(BuildContext context, String path) {
    if (path.isEmpty || !File(path).existsSync()) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
          child: InteractiveViewer(
            maxScale: 8,
            child: Image.file(File(path), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _embedBuilder(BuildContext context, EmbedNode node) {
    if (node.value.type == kImageEmbedType) {
      return _buildImageChip(context, node);
    }
    return defaultFleatherEmbedBuilder(context, node);
  }

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: custom.spacing.sm),
      child: FleatherTheme(
        data: buildFleatherTheme(
          context,
          fontFamily: custom.typography.fontFamily,
          strutStyle:
              widget.strutStyle ??
              StrutStyle(
                forceStrutHeight: true,
                fontSize: custom.typography.bodySize,
              ),
          compact: widget.compact,
        ),
        child: Builder(
          builder: (context) {
            // Read paragraph spacing from the Fleather theme so the placeholder
            // aligns with where the editor actually renders its first line.
            final fleatherTheme = FleatherTheme.of(context)!;
            final paragraphTop = fleatherTheme.paragraph.spacing.top;
            return Stack(
              children: [
                ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    overscroll: false,
                    physics: const _NoBounceScrollPhysics(),
                  ),
                  child: Focus(
                    onKeyEvent: _onKeyEvent,
                    child: FleatherEditor(
                      controller: _controller,
                      focusNode: _focusNode,
                      expands: widget.expands,
                      scrollPhysics: const _NoBounceScrollPhysics(),
                      embedBuilder: _embedBuilder,
                    ),
                  ),
                ),
                // Placeholder shown when content is empty
                if (_isEmpty && widget.placeholder != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Padding(
                        padding: EdgeInsets.only(top: paragraphTop),
                        child: AppText(
                          widget.placeholder!,
                          variant: AppTextVariant.body,
                          color: custom.colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
