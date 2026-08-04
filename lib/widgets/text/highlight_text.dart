import 'package:flutter/material.dart';

import 'package:re_highlight/re_highlight.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/theme/syntax_theme.dart';

/// 已编译语言缓存：re_highlight 按语言名注册/调用，这里按 [Mode] 实例
/// 复用 Highlight，避免重复注册与分配。
final Map<Mode, Highlight> _highlightCache = {};

/// re_highlight 按小写名查表（`getLanguage` 会 lowerCase 查询键），
/// 注册与调用必须使用同一小写名，否则会抛 Unknown language。
String _languageName(Mode language) =>
    (language.name ?? 'highlight').toLowerCase();

Highlight _highlightFor(Mode language) {
  final name = _languageName(language);
  return _highlightCache.putIfAbsent(
    language,
    () => Highlight()..registerLanguage(name, language),
  );
}

/// 将 [code] 按 [language] 高亮为 TextSpan（供自定义布局复用）。
///
/// 未匹配任何语法规则的内容回退为 [baseStyle]；主题表缺失的 scope 同理。
/// re_highlight 默认安全模式，解析异常不会抛出，流式半截文本可直接传入。
TextSpan highlightToSpan({
  required String code,
  required Mode language,
  required TextStyle baseStyle,
  required Map<String, TextStyle> theme,
}) {
  if (code.isEmpty) {
    return TextSpan(text: code, style: baseStyle);
  }
  final result = _highlightFor(language).highlight(
    code: code,
    language: _languageName(language),
  );
  final renderer = TextSpanRenderer(baseStyle, theme);
  result.render(renderer);
  return renderer.span ?? TextSpan(text: code, style: baseStyle);
}

/// 可复用语法高亮文本 — 无背景、按语言着色、可选中复制、可选横向滚动。
///
/// 基于 re_highlight 正则高亮：
/// - 主题默认由 [buildSyntaxTheme] 从应用设计 token 推导（跟随亮/暗模式），
///   也可用 [theme] 传入自定义 scope → 样式映射；
/// - 不绘制任何背景，适合嵌入卡片、消息流等已有容器；
/// - 文本可流式更新（安全模式容错，半截内容不会抛错）。
class HighlightText extends StatelessWidget {
  const HighlightText({
    super.key,
    required this.text,
    required this.language,
    this.theme,
    this.textStyle,
    this.selectable = true,
    this.horizontalScroll = false,
  });

  /// 待高亮文本（可为流式更新中的半截内容）
  final String text;

  /// 语言语法定义，如 `package:re_highlight/languages/diff.dart` 的 `langDiff`
  final Mode language;

  /// 高亮主题：scope 名 → 文字样式；为空时按当前 CustomTheme 推导
  final Map<String, TextStyle>? theme;

  /// 基础文字样式（字体/字号/行高）；未提供时用 caption 尺寸 + 主文字色
  final TextStyle? textStyle;

  /// 是否允许选中复制（默认开启）
  final bool selectable;

  /// 是否支持横向滚动（长行不被截断）
  final bool horizontalScroll;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    final custom = CustomTheme.of(context);
    final base = textStyle ??
        custom.typography.styleForSize(
          custom.typography.captionSize,
          custom.colors.textPrimary,
        );
    final span = highlightToSpan(
      code: text,
      language: language,
      baseStyle: base,
      theme: theme ?? buildSyntaxTheme(custom.colors),
    );
    final rich = selectable
        ? SelectableText.rich(span, style: base)
        : Text.rich(span, style: base);
    if (!horizontalScroll) {
      return rich;
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: rich,
    );
  }
}
