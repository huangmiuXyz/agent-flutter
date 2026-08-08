import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/ansi_text.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';
import 'package:agent/widgets/text/paragraph_utils.dart';
import 'package:agent/widgets/text/virtual_paragraph_text.dart';

/// 可展开/收起的 Part 卡片 — 通用组件
///
/// 统一渲染 [tool_call] 和 [tool_result]，展开后显示调用参数和可选的执行结果。
/// 收起高度由主题 token 控制，展开内容按自然高度完整展示，内部不滚动。
class ChatExpandablePart extends HookWidget {
  /// JSON 序列化的调用内容
  final String content;

  /// 左侧图标名称（注册在 AppIcon 中）
  final String iconName;

  /// 标题文字
  final String title;

  /// 标题颜色
  final Color titleColor;

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

  /// 展开内容左侧是否显示竖分割线（深度思考保留，工具调用去掉）
  final bool showLeftDivider;

  /// 是否默认展开（工具调用默认展开，深度思考默认收起）
  final bool initiallyExpanded;

  /// 展开区内容是否贴底自动滚动：内容增长（如深度思考流式输出）时
  /// 自动滚到底部；用户主动上滚后暂停，回到底部附近才恢复
  final bool stickToBottom;

  const ChatExpandablePart({
    super.key,
    required this.content,
    required this.iconName,
    required this.title,
    required this.titleColor,
    this.resultContent,
    this.children,
    this.argumentsBuilder,
    this.showLeftDivider = true,
    this.initiallyExpanded = false,
    this.stickToBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final expandedState = useState(initiallyExpanded);
    final isExpanded = expandedState.value;

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
        // 纯文本工具输出：剥离 `exit code: N` 前缀（仅供模型判断成败，
        // UI 展示命令输出时无需显示）
        resultText = stripExitCodeLine(rawResult);
      }
    }

    final collapsedHeight = custom.controls.chatPartCollapsedHeight;

    final resultAvailable = resultText != null && resultText.isNotEmpty;
    final hasContent = argumentsText.isNotEmpty || resultAvailable;

    // argumentsBuilder / children 渲染的是 widget 而非纯文本，
    // 无法并入 VirtualParagraphText，独立渲染（同样不滚动）
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

    // 输入段落用次级文字色，输出段落用成功色；两者之间渲染分隔线。
    // 输出段落经 ANSI 解析渲染彩色（shell_command 等工具输出保留颜色码），
    // 无颜色码时回落到段落默认色。
    Widget paragraphBuilder(ParagraphBlock paragraph, int index) {
      final isOutputSection =
          customWidgetsExist || index >= inputParagraphCount;
      final baseStyle = TextStyle(
        // 字体跟随主题设置（默认 JetBrainsMono）
        fontFamily: custom.typography.fontFamily ?? kDefaultFontFamily,
        fontSize: custom.typography.captionSize,
        height: 18 / custom.typography.captionSize,
        color: isOutputSection
            ? custom.colors.success
            : custom.colors.textSecondary,
      );
      final text = SelectableText.rich(
        TextSpan(
          style: baseStyle,
          children: AnsiTextParser().parse(
            paragraph.text,
            baseStyle: baseStyle,
          ),
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
          onTap: () {
            expandedState.value = !expandedState.value;
          },
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
                    isExpanded ? 'chevronDown' : 'chevronRight',
                    size: custom.typography.captionSize,
                    color: custom.colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── 展开内容 ──
        // 底部不留 padding：展开态与收起态的视觉间距必须一致（均为 8px）
        if (isExpanded && hasContent)
          Padding(
            padding: EdgeInsets.fromLTRB(0, 0, custom.spacing.sm, 0),
            child: Padding(
              padding: EdgeInsets.only(left: showLeftDivider ? 6 : 0),
              child: Container(
                decoration: showLeftDivider
                    ? BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: custom.colors.separator,
                            width: 1,
                          ),
                        ),
                      )
                    : null,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: showLeftDivider ? custom.spacing.sm : 0,
                  ),
                  child: Container(
                    width: double.infinity,
                    // 工具调用（无分割线）时左侧与上方不留边距，内容完全贴左贴顶
                    padding: EdgeInsets.fromLTRB(
                      showLeftDivider ? custom.spacing.sm : 0,
                      showLeftDivider ? custom.spacing.sm : 0,
                      custom.spacing.sm,
                      0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 自定义 widget 内容（apply_patch diff / 附加子内容）
                        if (customWidgetsExist)
                          Column(
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
                        // 自定义内容与输出之间的分隔线
                        if (customWidgetsExist && resultAvailable) ...[
                          SizedBox(height: custom.spacing.sm),
                          Container(height: 1, color: custom.colors.separator),
                          SizedBox(height: custom.spacing.sm),
                        ],
                        // 输入与输出共用同一个 VirtualParagraphText
                        // 短内容按自然高度完整展示；超过 chatPartExpandedMaxHeight 时
                        // 虚拟滚动（只构建可见段落），避免大输出（如 `ls -R .`）
                        // 一次性构建数十万段落导致 UI 卡死。
                        VirtualParagraphText(
                          text: virtualText,
                          splitMode: ParagraphSplitMode.newline,
                          fontSize: custom.typography.captionSize,
                          lineHeight: 18,
                          maxHeight: custom.controls.chatPartExpandedMaxHeight,
                          paragraphPaddingBlock: 0,
                          paragraphGap: 4,
                          // 内容增长时自动滚动到底部（深度思考流式输出跟随）
                          stickToBottom: stickToBottom,
                          bottomThreshold: 0,
                          paragraphBuilder: paragraphBuilder,
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
