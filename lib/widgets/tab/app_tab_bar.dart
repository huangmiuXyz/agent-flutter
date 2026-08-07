/// A simple segmented tab bar built from custom styled buttons.
///
/// Does NOT depend on Flutter's [TabBar]/[TabBarView] — instead it renders
/// a row of tappable segments and leaves content switching to the caller
/// via [activeIndex] / [onChanged].
library;

import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Visual size variants for [AppTabBar].
enum TabBarSize { sm, md, lg }

/// A horizontal row of tab segments.
///
/// ```dart
/// AppTabBar(
///   tabs: const ['工具', '资源'],
///   activeIndex: activeTab.value,
///   onChanged: (i) => activeTab.value = i,
///   size: TabBarSize.md,
/// )
/// ```
class AppTabBar extends StatelessWidget {
  /// The label for each tab segment.
  final List<String> tabs;

  /// The index of the currently active tab.
  final int activeIndex;

  /// Called when the user taps a tab.
  final ValueChanged<int> onChanged;

  /// Visual size. Defaults to [TabBarSize.md].
  final TabBarSize size;

  const AppTabBar({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onChanged,
    this.size = TabBarSize.md,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final sizing = _resolveSizing(custom);

    return Container(
      decoration: BoxDecoration(
        color: custom.colors.panel,
        borderRadius: sizing.borderRadius,
      ),
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++)
            Expanded(
              child: _TabSegment(
                label: tabs[i],
                active: activeIndex == i,
                height: sizing.height,
                fontSize: sizing.fontSize,
                fontWeight: activeIndex == i
                    ? FontWeight.w600
                    : FontWeight.normal,
                activeColor: custom.colors.accent,
                inactiveColor: custom.colors.textSecondary,
                borderRadius: sizing.borderRadius,
                onTap: () => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }

  _TabBarSizing _resolveSizing(CustomTheme custom) {
    switch (size) {
      case TabBarSize.sm:
        return _TabBarSizing(
          height: custom.controls.smallHeight,
          fontSize: custom.typography.captionSize,
          borderRadius: custom.radii.xs,
        );
      case TabBarSize.md:
        return _TabBarSizing(
          height: custom.controls.mediumHeight,
          fontSize: custom.typography.bodySize,
          borderRadius: custom.radii.xs,
        );
      case TabBarSize.lg:
        return _TabBarSizing(
          height: custom.controls.largeHeight,
          fontSize: custom.typography.subtitleSize,
          borderRadius: custom.radii.sm,
        );
    }
  }
}

/// Internal sizing constants.
class _TabBarSizing {
  final double height;
  final double fontSize;
  final BorderRadius borderRadius;

  const _TabBarSizing({
    required this.height,
    required this.fontSize,
    required this.borderRadius,
  });
}

/// A single tab segment.
class _TabSegment extends StatelessWidget {
  final String label;
  final bool active;
  final double height;
  final double fontSize;
  final FontWeight fontWeight;
  final Color activeColor;
  final Color inactiveColor;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  const _TabSegment({
    required this.label,
    required this.active,
    required this.height,
    required this.fontSize,
    required this.fontWeight,
    required this.activeColor,
    required this.inactiveColor,
    required this.borderRadius,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: borderRadius,
          border: active
              ? Border(bottom: BorderSide(color: activeColor, width: 2))
              : null,
        ),
        child: AppText(
          label,
          style: TextStyle(
            color: active ? activeColor : inactiveColor,
            fontWeight: fontWeight,
            fontSize: fontSize,
          ),
        ),
      ),
    );
  }
}
