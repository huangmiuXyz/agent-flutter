import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 本地捆绑字体名（JetBrainsMono 已打包在 assets 中，无需网络）。
const String kDefaultFontFamily = 'JetBrainsMono';

/// Google Fonts 全部 family 名集合（惰性缓存，首次访问时构建）。
final Set<String> _googleFontFamilies = GoogleFonts.asMap().keys.toSet();

/// 构建 [TextStyle]：按字体来源分流——
/// 1. 默认字体走本地捆绑；
/// 2. Google Fonts 字体走 [GoogleFonts] 云端加载；
/// 3. 其余（本机系统字体、导入字体）直接按 family 名引用，由系统引擎解析。
TextStyle textStyleForFont(
  String fontFamily, {
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
}) {
  if (fontFamily == kDefaultFontFamily) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
  if (_googleFontFamilies.contains(fontFamily)) {
    return GoogleFonts.getFont(
      fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
  // 系统字体 / 已导入字体：直接引用，Flutter 桌面端通过
  // DirectWrite/CoreText 解析本机字体，FontLoader 解析已注册字体。
  return TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );
}

/// Available Google Font options for display settings.
const List<Map<String, String>> kFontOptions = [
  // ── 本地捆绑（无需网络） ──
  {'label': 'JetBrains Mono', 'family': 'JetBrainsMono'},

  // ── 中文/日文/韩文 ──
  {'label': 'Noto Sans SC', 'family': 'Noto Sans SC'},
  {'label': 'Noto Sans TC', 'family': 'Noto Sans TC'},
  {'label': 'Noto Sans JP', 'family': 'Noto Sans JP'},
  {'label': 'Noto Sans KR', 'family': 'Noto Sans KR'},
  {'label': 'Noto Serif SC', 'family': 'Noto Serif SC'},
  {'label': 'Source Han Sans SC', 'family': 'Source Han Sans SC'},
  {'label': 'Source Han Serif SC', 'family': 'Source Han Serif SC'},
  {'label': 'Ma Shan Zheng', 'family': 'Ma Shan Zheng'},
  {'label': 'ZCOOL XiaoWei', 'family': 'ZCOOL XiaoWei'},
  {'label': 'ZCOOL QingKe HuangYou', 'family': 'ZCOOL QingKe HuangYou'},
  {'label': 'Liu Jian Mao Cao', 'family': 'Liu Jian Mao Cao'},
  {'label': 'Zhi Mang Xing', 'family': 'Zhi Mang Xing'},
  {'label': 'Long Cang', 'family': 'Long Cang'},

  // ── 无衬线体 ──
  {'label': 'Inter', 'family': 'Inter'},
  {'label': 'Roboto', 'family': 'Roboto'},
  {'label': 'Noto Sans', 'family': 'Noto Sans'},
  {'label': 'Open Sans', 'family': 'Open Sans'},
  {'label': 'Lato', 'family': 'Lato'},
  {'label': 'Montserrat', 'family': 'Montserrat'},
  {'label': 'Poppins', 'family': 'Poppins'},
  {'label': 'Nunito', 'family': 'Nunito'},
  {'label': 'Ubuntu', 'family': 'Ubuntu'},
  {'label': 'Rubik', 'family': 'Rubik'},
  {'label': 'Manrope', 'family': 'Manrope'},
  {'label': 'Figtree', 'family': 'Figtree'},
  {'label': 'Plus Jakarta Sans', 'family': 'Plus Jakarta Sans'},
  {'label': 'DM Sans', 'family': 'DM Sans'},
  {'label': 'Work Sans', 'family': 'Work Sans'},
  {'label': 'Outfit', 'family': 'Outfit'},
  {'label': 'Sora', 'family': 'Sora'},
  {'label': 'Onest', 'family': 'Onest'},

  // ── 衬线体 ──
  {'label': 'Noto Serif', 'family': 'Noto Serif'},
  {'label': 'Merriweather', 'family': 'Merriweather'},
  {'label': 'Playfair Display', 'family': 'Playfair Display'},
  {'label': 'Lora', 'family': 'Lora'},
  {'label': 'PT Serif', 'family': 'PT Serif'},
  {'label': 'Source Serif 4', 'family': 'Source Serif 4'},
  {'label': 'Bitter', 'family': 'Bitter'},
  {'label': 'Libre Baskerville', 'family': 'Libre Baskerville'},

  // ── 等宽字体 ──
  {'label': 'Fira Code', 'family': 'Fira Code'},
  {'label': 'Cascadia Code', 'family': 'Cascadia Code'},
  {'label': 'Source Code Pro', 'family': 'Source Code Pro'},
  {'label': 'IBM Plex Mono', 'family': 'IBM Plex Mono'},
  {'label': 'Space Mono', 'family': 'Space Mono'},
  {'label': 'Victor Mono', 'family': 'Victor Mono'},
  {'label': 'Inconsolata', 'family': 'Inconsolata'},
  {'label': 'Fira Mono', 'family': 'Fira Mono'},
  {'label': 'Courier Prime', 'family': 'Courier Prime'},

  // ── 展示/装饰字体 ──
  {'label': 'Pacifico', 'family': 'Pacifico'},
  {'label': 'Dancing Script', 'family': 'Dancing Script'},
  {'label': 'Caveat', 'family': 'Caveat'},
  {'label': 'Kalam', 'family': 'Kalam'},
  {'label': 'Rowdies', 'family': 'Rowdies'},
  {'label': 'Bebas Neue', 'family': 'Bebas Neue'},
  {'label': 'Anton', 'family': 'Anton'},
  {'label': 'Righteous', 'family': 'Righteous'},
];

@immutable
class AppSpacing {
  const AppSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 16,
    this.lg = 24,
    this.xl = 32,
    this.pageTop = 70,
    this.pageBottom = 60,
    // Edge margin for context menus and overlays
    this.edgeMargin = 12,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double pageTop;
  final double pageBottom;
  final double edgeMargin;

  static AppSpacing lerp(AppSpacing a, AppSpacing b, double t) => AppSpacing(
    xs: lerpDouble(a.xs, b.xs, t)!,
    sm: lerpDouble(a.sm, b.sm, t)!,
    md: lerpDouble(a.md, b.md, t)!,
    lg: lerpDouble(a.lg, b.lg, t)!,
    xl: lerpDouble(a.xl, b.xl, t)!,
    pageTop: lerpDouble(a.pageTop, b.pageTop, t)!,
    pageBottom: lerpDouble(a.pageBottom, b.pageBottom, t)!,
    edgeMargin: lerpDouble(a.edgeMargin, b.edgeMargin, t)!,
  );
}

@immutable
class AppRadii {
  const AppRadii({
    required this.xs,
    required this.sm,
    required this.md,
    required this.full,
  });

  factory AppRadii.defaults() => const AppRadii(
    xs: BorderRadius.all(Radius.circular(4)),
    sm: BorderRadius.all(Radius.circular(8)),
    md: BorderRadius.all(Radius.circular(12)),
    full: BorderRadius.all(Radius.circular(999)),
  );

  final BorderRadius xs;
  final BorderRadius sm;
  final BorderRadius md;
  final BorderRadius full;

  static AppRadii lerp(AppRadii a, AppRadii b, double t) => AppRadii(
    xs: BorderRadius.lerp(a.xs, b.xs, t)!,
    sm: BorderRadius.lerp(a.sm, b.sm, t)!,
    md: BorderRadius.lerp(a.md, b.md, t)!,
    full: BorderRadius.lerp(a.full, b.full, t)!,
  );
}

@immutable
class AppControls {
  const AppControls({
    this.smallHeight = 24,
    this.mediumHeight = 32,
    this.largeHeight = 40,
    // Switch-specific sizes (fixed width × height, no computation)
    this.switchSmHeight = 16,
    this.switchSmWidth = 28,
    this.switchMdHeight = 20,
    this.switchMdWidth = 36,
    this.switchLgHeight = 24,
    this.switchLgWidth = 40,
    // Dialog
    this.dialogWidth = 420,
    // Context menu
    this.contextMenuMinWidth = 128,
    this.contextMenuSubmenuWidth = 192,
    this.contextMenuMaxWidth = 320,
    // Tab bar
    this.tabAddButtonWidth = 28,
    // Execute panel
    this.executePanelHeight = 200,
    this.footerHeight = 26,
    // Chat part card sizing
    this.chatPartCollapsedHeight = 32,
    this.chatPartExpandedMaxHeight = 320,
  });

  final double smallHeight;
  final double mediumHeight;
  final double largeHeight;
  final double switchSmHeight;
  final double switchSmWidth;
  final double switchMdHeight;
  final double switchMdWidth;
  final double switchLgHeight;
  final double switchLgWidth;
  final double dialogWidth;
  final double contextMenuMinWidth;
  final double contextMenuSubmenuWidth;
  final double contextMenuMaxWidth;
  final double tabAddButtonWidth;
  final double executePanelHeight;
  final double footerHeight;
  final double chatPartCollapsedHeight;
  final double chatPartExpandedMaxHeight;

  static AppControls lerp(AppControls a, AppControls b, double t) =>
      AppControls(
        smallHeight: lerpDouble(a.smallHeight, b.smallHeight, t)!,
        mediumHeight: lerpDouble(a.mediumHeight, b.mediumHeight, t)!,
        largeHeight: lerpDouble(a.largeHeight, b.largeHeight, t)!,
        switchSmHeight: lerpDouble(a.switchSmHeight, b.switchSmHeight, t)!,
        switchSmWidth: lerpDouble(a.switchSmWidth, b.switchSmWidth, t)!,
        switchMdHeight: lerpDouble(a.switchMdHeight, b.switchMdHeight, t)!,
        switchMdWidth: lerpDouble(a.switchMdWidth, b.switchMdWidth, t)!,
        switchLgHeight: lerpDouble(a.switchLgHeight, b.switchLgHeight, t)!,
        switchLgWidth: lerpDouble(a.switchLgWidth, b.switchLgWidth, t)!,
        dialogWidth: lerpDouble(a.dialogWidth, b.dialogWidth, t)!,
        contextMenuMinWidth: lerpDouble(
          a.contextMenuMinWidth,
          b.contextMenuMinWidth,
          t,
        )!,
        contextMenuSubmenuWidth: lerpDouble(
          a.contextMenuSubmenuWidth,
          b.contextMenuSubmenuWidth,
          t,
        )!,
        contextMenuMaxWidth: lerpDouble(
          a.contextMenuMaxWidth,
          b.contextMenuMaxWidth,
          t,
        )!,
        tabAddButtonWidth: lerpDouble(
          a.tabAddButtonWidth,
          b.tabAddButtonWidth,
          t,
        )!,
        executePanelHeight: lerpDouble(
          a.executePanelHeight,
          b.executePanelHeight,
          t,
        )!,
        footerHeight: lerpDouble(a.footerHeight, b.footerHeight, t)!,
        chatPartCollapsedHeight: lerpDouble(
          a.chatPartCollapsedHeight,
          b.chatPartCollapsedHeight,
          t,
        )!,
        chatPartExpandedMaxHeight: lerpDouble(
          a.chatPartExpandedMaxHeight,
          b.chatPartExpandedMaxHeight,
          t,
        )!,
      );
}

@immutable
class AppTypography {
  const AppTypography({
    this.fontFamily = kDefaultFontFamily,
    this.captionSize = 12,
    this.bodySize = 14,
    this.subtitleSize = 16,
    this.titleSize = 18,
    this.heading2Size = 24,
    this.heading1Size = 32,
    this.bodyWeight = FontWeight.w400,
    this.fontSizeScale = 1.0,
  });

  final String? fontFamily;
  final double captionSize;
  final double bodySize;
  final double subtitleSize;
  final double titleSize;
  final double heading2Size;
  final double heading1Size;
  final FontWeight bodyWeight;

  /// 全局字号缩放系数（1.0 = 原始大小），供硬编码字号的组件读取。
  final double fontSizeScale;

  String? get effectiveFontFamily => fontFamily;

  AppTypography copyWith({
    String? fontFamily,
    FontWeight? bodyWeight,
    double? fontSizeScale,
  }) {
    final scale = fontSizeScale ?? this.fontSizeScale;
    return AppTypography(
      fontFamily: fontFamily ?? this.fontFamily,
      captionSize: captionSize * scale,
      bodySize: bodySize * scale,
      subtitleSize: subtitleSize * scale,
      titleSize: titleSize * scale,
      heading2Size: heading2Size * scale,
      heading1Size: heading1Size * scale,
      bodyWeight: bodyWeight ?? this.bodyWeight,
      fontSizeScale: scale,
    );
  }

  TextStyle styleForSize(double size, Color color, {FontWeight? weight}) {
    final effectiveWeight = weight ?? bodyWeight;
    return textStyleForFont(
      fontFamily ?? kDefaultFontFamily,
      fontSize: size,
      fontWeight: effectiveWeight,
      color: color,
    );
  }

  static AppTypography lerp(AppTypography a, AppTypography b, double t) =>
      AppTypography(
        fontFamily: t < 0.5 ? a.fontFamily : b.fontFamily,
        captionSize: lerpDouble(a.captionSize, b.captionSize, t)!,
        bodySize: lerpDouble(a.bodySize, b.bodySize, t)!,
        subtitleSize: lerpDouble(a.subtitleSize, b.subtitleSize, t)!,
        titleSize: lerpDouble(a.titleSize, b.titleSize, t)!,
        heading2Size: lerpDouble(a.heading2Size, b.heading2Size, t)!,
        heading1Size: lerpDouble(a.heading1Size, b.heading1Size, t)!,
        bodyWeight: t < 0.5 ? a.bodyWeight : b.bodyWeight,
        fontSizeScale: t < 0.5 ? a.fontSizeScale : b.fontSizeScale,
      );

  /// Returns a copy scaled by [factor].
  AppTypography scale(double factor) => AppTypography(
    fontFamily: fontFamily,
    captionSize: captionSize * factor,
    bodySize: bodySize * factor,
    subtitleSize: subtitleSize * factor,
    titleSize: titleSize * factor,
    heading2Size: heading2Size * factor,
    heading1Size: heading1Size * factor,
    bodyWeight: bodyWeight,
    fontSizeScale: fontSizeScale * factor,
  );
}

@immutable
class AppShadows {
  const AppShadows({
    required this.small,
    required this.medium,
    required this.large,
  });

  factory AppShadows.forBrightness(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return AppShadows(
      small: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.20 : 0.08),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
      medium: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.25 : 0.10),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
      large: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.30 : 0.12),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  final List<BoxShadow> small;
  final List<BoxShadow> medium;
  final List<BoxShadow> large;

  static AppShadows lerp(AppShadows a, AppShadows b, double t) => AppShadows(
    small: BoxShadow.lerpList(a.small, b.small, t)!,
    medium: BoxShadow.lerpList(a.medium, b.medium, t)!,
    large: BoxShadow.lerpList(a.large, b.large, t)!,
  );
}
