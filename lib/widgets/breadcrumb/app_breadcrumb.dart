/// App Breadcrumb
///
/// Lightweight breadcrumb navigation built with existing components.
///
/// ```dart
/// AppBreadcrumb(items: [
///   AppBreadcrumbItem('Settings', onTap: () => ...),
///   AppBreadcrumbItem('Models', onTap: () => ...),
///   AppBreadcrumbItem('DeepSeek'),  // current page, no onTap
/// ])
/// ```
library;

import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';

/// A single item in the breadcrumb trail.
class AppBreadcrumbItem {
  /// Display text.
  final String label;

  /// When null, the item is rendered as plain text (current page).
  /// When provided, the item is rendered as a clickable link.
  final VoidCallback? onTap;

  const AppBreadcrumbItem(this.label, {this.onTap});
}

class AppBreadcrumb extends StatelessWidget {
  /// The trail of breadcrumb items.
  ///
  /// The last item is rendered as plain text (current location).
  /// All preceding items with [AppBreadcrumbItem.onTap] are rendered as
  /// clickable links.
  final List<AppBreadcrumbItem> items;

  /// Custom separator widget. Defaults to a chevron-right icon.
  final Widget? separator;

  const AppBreadcrumb({super.key, required this.items, this.separator});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    final effectiveSeparator =
        separator ??
        Padding(
          padding: EdgeInsets.symmetric(horizontal: custom.spacing.xs),
          child: AppIcon(
            'chevronRight',
            size: custom.typography.captionSize,
            color: custom.colors.textDisabled,
          ),
        );

    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) effectiveSeparator,
          _buildItem(context, custom, items[i], i == items.length - 1),
        ],
      ],
    );
  }

  Widget _buildItem(
    BuildContext context,
    CustomTheme custom,
    AppBreadcrumbItem item,
    bool isLast,
  ) {
    if (isLast || item.onTap == null) {
      return AppText(
        item.label,
        variant: AppTextVariant.caption,
        color: custom.colors.textSecondary,
      );
    }

    return _BreadcrumbLink(label: item.label, onTap: item.onTap!);
  }
}

class _BreadcrumbLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _BreadcrumbLink({required this.label, required this.onTap});

  @override
  State<_BreadcrumbLink> createState() => _BreadcrumbLinkState();
}

class _BreadcrumbLinkState extends State<_BreadcrumbLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AppText(
          widget.label,
          variant: AppTextVariant.caption,
          color: _hovered ? custom.colors.accent : custom.colors.textDisabled,
        ),
      ),
    );
  }
}
