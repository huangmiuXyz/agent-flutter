import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';
import 'package:agent/widgets/text/virtual_paragraph_text.dart';

/// 可展开/收起的 Part 卡片 — 通用组件
///
/// 统一渲染 [tool_call] 和 [tool_result]，展开后显示调用参数和可选的执行结果。
/// 展开/收起高度由主题 token 统一控制。
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

  const ChatExpandablePart({
    super.key,
    required this.content,
    required this.iconName,
    required this.title,
    required this.titleColor,
    this.defaultExpanded = true,
    this.resultContent,
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

    // 解析调用参数 — 只显示 arguments，不显示 id/type/function 外层
    String argumentsText;
    try {
      final json = jsonDecode(content);
      String raw;
      if (json is Map<String, dynamic>) {
        // tool_call: {function: {arguments: "{...}"}}
        final func = json['function'];
        if (func is Map<String, dynamic> && func['arguments'] is String) {
          raw = func['arguments'] as String;
        } else if (json['arguments'] is String) {
          // tool_call_frag: {arguments: "{...}"}
          raw = json['arguments'] as String;
        } else {
          raw = const JsonEncoder.withIndent('  ').convert(json);
        }
      } else {
        raw = const JsonEncoder.withIndent('  ').convert(json);
      }
      // arguments 本身可能是 JSON，尝试格式化
      try {
        argumentsText = const JsonEncoder.withIndent(
          '  ',
        ).convert(jsonDecode(raw));
      } catch (_) {
        argumentsText = raw;
      }
    } catch (_) {
      argumentsText = content;
    }

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
    final expandedMaxHeight = custom.controls.chatPartExpandedMaxHeight;

    final resultAvailable = resultText != null && resultText.isNotEmpty;
    final hasContent = argumentsText.isNotEmpty || resultAvailable;

    return Container(
      child: Column(
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
                custom.spacing.sm,
                0,
                custom.spacing.sm,
                custom.spacing.xs,
              ),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(maxHeight: expandedMaxHeight),
                padding: EdgeInsets.all(custom.spacing.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 参数（固定头部） ──
                    SelectableText(
                      argumentsText,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: custom.typography.captionSize,
                        color: custom.colors.textSecondary,
                      ),
                    ),

                    // ── 结果分隔 + 虚拟滚动结果 ──
                    if (resultText != null && resultText.isNotEmpty) ...[
                      SizedBox(height: custom.spacing.sm),
                      Container(height: 1, color: custom.colors.separator),
                      SizedBox(height: custom.spacing.sm),
                      VirtualParagraphText(
                        text: resultText,
                        splitMode: ParagraphSplitMode.newline,
                        maxHeight: expandedMaxHeight,
                        fontSize: custom.typography.captionSize,
                        lineHeight: 18,
                        paragraphPaddingBlock: 0,
                        paragraphGap: 4,
                        paragraphBuilder: (paragraph, index) {
                          return SelectableText(
                            paragraph.text,
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: custom.typography.captionSize,
                              color: custom.colors.success,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
