import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';
import 'package:agent/widgets/text/paragraph_utils.dart';
import 'package:agent/widgets/text/virtual_paragraph_text.dart';

/// 可展开/收起的 Part 卡片 — 通用组件
///
/// 统一渲染 [tool_call] 和 [tool_result]，展开后显示调用参数和可选的执行结果。
/// 收起高度由主题 token 控制，展开内容最大高度取视口高度。
class ChatExpandablePart extends HookWidget {
  /// JSON 序列化的调用内容
  final String content;

  /// 左侧图标名称（注册在 AppIcon 中）
  final String iconName;

  /// 标题文字
  final String title;

  /// 标题颜色
  final Color titleColor;

  /// 是否默认展开
  final bool defaultExpanded;

  /// 可选的工具执行结果（JSON），有值时在展开区显示在参数下方
  final String? resultContent;

  /// 展开区内可选的子内容（如思考阶段发起的联网搜索标签、后续思考文本段），
  /// 渲染在正文下方，元素之间仅以间距隔开
  final List<Widget>? children;

  /// 展开区正文自定义构建器：替换默认的「参数文本」渲染。
  /// 入参为解析出的原始 arguments 字符串（未做 JSON 格式化），
  /// 典型用途：apply_patch 工具用 diff 代码块渲染 patch 参数。
  final Widget Function(BuildContext context, String rawArguments)?
  argumentsBuilder;

  const ChatExpandablePart({
    super.key,
    required this.content,
    required this.iconName,
    required this.title,
    required this.titleColor,
    this.defaultExpanded = true,
    this.resultContent,
    this.children,
    this.argumentsBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final expanded = useState(defaultExpanded);
    // 当 defaultExpanded 变化时同步展开/收起状态
    // （例如新消息到达后，前一条消息不再是最后一个 expandable part）
    useEffect(() {
      expanded.value = defaultExpanded;
      return null;
    }, [defaultExpanded]);

    // 解析调用参数 — 统一格式：{id, call_type, function: {name, arguments}, _result?}
    // 保留原始 arguments（供 argumentsBuilder 二次解析），另存格式化文本
    String rawArguments = content;
    try {
      final json = jsonDecode(content);
      if (json is Map<String, dynamic>) {
        final func = json['function'];
        if (func is Map<String, dynamic> && func['arguments'] is String) {
          rawArguments = func['arguments'] as String;
        } else {
          rawArguments = const JsonEncoder.withIndent('  ').convert(json);
        }
      } else {
        rawArguments = const JsonEncoder.withIndent('  ').convert(json);
      }
    } catch (_) {
      rawArguments = content;
    }

    // arguments 本身可能是 JSON，尝试格式化
    String argumentsText = rawArguments;
    try {
      argumentsText = const JsonEncoder.withIndent(
        '  ',
      ).convert(jsonDecode(rawArguments));
    } catch (_) {}

    // 解析结果内容
    final rawResult = resultContent;
    String? resultText;
    if (rawResult != null && rawResult.isNotEmpty) {
      try {
        final json = jsonDecode(rawResult);
        resultText = const JsonEncoder.withIndent('  ').convert(json);
      } catch (_) {
        resultText = rawResult;
      }
    }

    final collapsedHeight = custom.controls.chatPartCollapsedHeight;
    // 滚动阈值：展开内容最大高度取视口高度，而非固定主题 token
    final viewportHeight = MediaQuery.sizeOf(context).height;

    final resultAvailable = resultText != null && resultText.isNotEmpty;
    final hasContent = argumentsText.isNotEmpty || resultAvailable;

    // argumentsBuilder / children 渲染的是 widget 而非纯文本，
    // 无法并入 VirtualParagraphText，保留独立滚动区域
    final customWidgetsExist =
        argumentsBuilder != null || (children != null && children!.isNotEmpty);

    // 输入(参数)与输出(结果)合并为同一段文本，共用同一个 VirtualParagraphText；
    // 输入段落在前，输出段落紧随其后，均按换行拆分为段落
    final inputParagraphCount = splitTextIntoParagraphs(
      argumentsText,
      mode: ParagraphSplitMode.newline,
    ).length;
    final virtualText = customWidgetsExist
        ? (resultText ?? '')
        : resultAvailable
        ? '$argumentsText\n\n$resultText'
        : argumentsText;

    // 输入段落用次级文字色，输出段落用成功色；两者之间渲染分隔线
    Widget paragraphBuilder(ParagraphBlock paragraph, int index) {
      final isOutputSection =
          customWidgetsExist || index >= inputParagraphCount;
      final text = SelectableText(
        paragraph.text,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: custom.typography.captionSize,
          height: 18 / custom.typography.captionSize,
          color: isOutputSection
              ? custom.colors.success
              : custom.colors.textSecondary,
        ),
      );
      final showDivider =
          !customWidgetsExist &&
          resultAvailable &&
          inputParagraphCount > 0 &&
          index == inputParagraphCount;
      if (!showDivider) return text;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: custom.spacing.sm,
              bottom: custom.spacing.sm,
            ),
            child: Container(height: 1, color: custom.colors.separator),
          ),
          text,
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 头部（可点击切换展开/收起） ──
        InkWell(
          onTap: () => expanded.value = !expanded.value,
          borderRadius: custom.radii.sm,
          child: SizedBox(
            height: collapsedHeight,
            child: Padding(
              padding: EdgeInsets.only(right: custom.spacing.sm),
              child: Row(
                children: [
                  AppIcon(
                    iconName,
                    size: custom.typography.captionSize,
                    color: titleColor,
                  ),
                  SizedBox(width: custom.spacing.xs),
                  Expanded(
                    child: AppText(
                      title,
                      variant: AppTextVariant.caption,
                      color: titleColor,
                    ),
                  ),
                  AppIcon(
                    expanded.value ? 'chevronDown' : 'chevronRight',
                    size: custom.typography.captionSize,
                    color: custom.colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── 展开内容 ──
        if (expanded.value && hasContent)
          Padding(
            padding: EdgeInsets.fromLTRB(
              0,
              0,
              custom.spacing.sm,
              custom.spacing.xs,
            ),
            child: Padding(
              padding: EdgeInsets.only(left: 6),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: custom.colors.separator, width: 1),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(left: custom.spacing.sm),
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxHeight: viewportHeight),
                    padding: EdgeInsets.all(custom.spacing.sm),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 自定义 widget 内容（apply_patch diff / 附加子内容）
                        if (customWidgetsExist)
                          Flexible(
                            fit: FlexFit.loose,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (argumentsBuilder != null)
                                    argumentsBuilder!(context, rawArguments),
                                  if (children != null && children!.isNotEmpty)
                                    for (final child in children!)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          top: custom.spacing.sm,
                                        ),
                                        child: child,
                                      ),
                                ],
                              ),
                            ),
                          ),
                        // 自定义内容与输出之间的分隔线
                        if (customWidgetsExist && resultAvailable) ...[
                          SizedBox(height: custom.spacing.sm),
                          Container(height: 1, color: custom.colors.separator),
                          SizedBox(height: custom.spacing.sm),
                        ],
                        // 输入与输出共用同一个 VirtualParagraphText
                        Flexible(
                          fit: FlexFit.loose,
                          child: VirtualParagraphText(
                            text: virtualText,
                            splitMode: ParagraphSplitMode.newline,
                            maxHeight: viewportHeight,
                            fontSize: custom.typography.captionSize,
                            lineHeight: 18,
                            paragraphPaddingBlock: 0,
                            paragraphGap: 4,
                            paragraphBuilder: paragraphBuilder,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
