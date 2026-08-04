import 'package:flutter/material.dart';

import 'package:agent/theme/app_colors.dart';

/// 基于应用设计 token 的 re_highlight 语法主题（scope 名 → 文字样式）。
///
/// 颜色取自 [AppColors]，随应用亮/暗主题切换自动适配；只使用前景色、
/// 不设置任何背景，符合「无背景高亮」的展示需求。未列出的 scope
/// 回退为调用方的基础文字样式。
Map<String, TextStyle> buildSyntaxTheme(AppColors colors) {
  final warningStyle = TextStyle(color: colors.warning);
  final successStyle = TextStyle(color: colors.success);
  final dangerStyle = TextStyle(color: colors.danger);
  final secondaryStyle = TextStyle(color: colors.textSecondary);
  final secondaryItalic = secondaryStyle.copyWith(fontStyle: FontStyle.italic);
  return {
    // 注释 / 元信息：次级色（注释加斜体）
    'comment': secondaryItalic,
    'quote': secondaryItalic,
    'doctag': secondaryItalic,
    'meta': secondaryStyle,
    'formula': secondaryStyle,
    // 关键字 / 类型 / 字面量：警示色
    'keyword': warningStyle,
    'type': warningStyle,
    'built_in': warningStyle,
    'literal': warningStyle,
    'number': warningStyle,
    // 字符串 / 属性：成功色
    'string': successStyle,
    'regexp': successStyle,
    'attribute': successStyle,
    'attr': successStyle,
    'meta-string': successStyle,
    // diff 语义
    'addition': successStyle,
    'deletion': dangerStyle,
  };
}
