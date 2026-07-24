/// App Big List Widgets
///
/// Opinionated wrappers built on top of [AppList]/[AppListItem] that replicate
/// the Electron settings list design pattern:
///
/// - [AppBigList] — outer shell with header (count + actions), search bar,
///   group slots, and empty state.
/// - [AppBigGroup] — card container with rounded corners + group label.
/// - [AppBigRow] — single row with optional leading icon/avatar, name,
///   description, status dot, and hover-revealed action buttons.
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';
import 'package:agent/widgets/list/app_list.dart';

// ---------------------------------------------------------------------------
// AppBigRow
// ---------------------------------------------------------------------------

/// A single row inside a [AppBigGroup], modeled after Electron's
/// `SettingsRow.vue`.
///
/// Built on top of [AppListItem] with a two-line layout (name + description),
/// optional leading icon/avatar, status dot, and hover-revealed action buttons.
///
/// ```dart
/// AppBigRow(
///   icon: 'robot',
///   name: '默认智能体',
///   description: '默认的智能体助手',
///   dot: true,
///   actions: [
///     AppIconButton(icon: 'pencil', onPressed: () {}),
///   ],
///   onTap: () {},
/// )
/// ```
class AppBigRow extends HookWidget {
  /// Custom leading widget (e.g. an avatar [Image]).
  ///
  /// When provided, [icon] is ignored.
  final Widget? leading;

  /// Icon name resolved via [AppIcon]. Used when [leading] is null.
  final String? icon;

  /// Title text (bold).
  final String name;

  /// Optional description text shown below the name in a smaller size.
  final String? description;

  /// When true, the name appears with reduced weight/color (secondary).
  final bool muted;

  /// When true, shows a small status dot at the bottom-right of the leading
  /// widget.
  final bool dot;

  /// Color of the status dot. Defaults to [AppColors.accent].
  final Color? dotColor;

  /// Whether the row responds to taps.
  final bool clickable;

  /// Called when the row is tapped.
  final VoidCallback? onTap;

  /// Optional action buttons shown on the trailing side.
  ///
  /// Always visible, unlike [AppListItem.hoverActions].
  final List<Widget>? actions;

  /// Whether the description text uses a monospace font.
  final bool mono;

  /// Visual size, inherited by the underlying [AppListItem].
  final AppListSize? size;

  /// Extra padding around the row content.
  final EdgeInsetsGeometry? padding;

  const AppBigRow({
    super.key,
    this.leading,
    this.icon,
    required this.name,
    this.description,
    this.muted = false,
    this.dot = false,
    this.dotColor,
    this.clickable = false,
    this.onTap,
    this.actions,
    this.mono = false,
    this.size,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isHovered = useState(false);

    final custom = CustomTheme.of(context);

    // Layout: [leading] + [name + desc] + [actions]
    // Uses a Column to allow the bottom border to span full width.

    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Row content ----
          AppListItem(
            size: size ?? AppListSize.small,
            intrinsicHeight: true,
            label: name,
            itemPadding:
                padding ??
                EdgeInsets.symmetric(
                  horizontal: custom.spacing.sm,
                  vertical: custom.spacing.xs + 2,
                ),
            onTap: clickable ? onTap : null,
            onHover: (hovered, _) => isHovered.value = hovered,
            // Leading icon/avatar
            labelWidget: _buildLeadingAndText(custom, isHovered),
            // Trailing actions (always visible)
            trailingWidget: actions != null
                ? Row(mainAxisSize: MainAxisSize.min, children: actions!)
                : null,
          ),
          // ---- Full-width bottom separator (matches Electron's ::after) ----
          Container(height: 1, color: custom.colors.separator),
        ],
      ),
    );
  }

  Widget _buildLeadingAndText(
    CustomTheme custom,
    ValueNotifier<bool> isHovered,
  ) {
    final foreground = muted
        ? custom.colors.textSecondary
        : custom.colors.textPrimary;

    return Row(
      children: [
        // ---- Leading widget ----
        _LeadingWidget(
          leading: leading,
          icon: icon,
          dot: dot,
          dotColor: dotColor,
          custom: custom,
          isHovered: isHovered,
        ),
        SizedBox(width: custom.spacing.sm + 2),
        // ---- Name + Description ----
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(name, variant: AppTextVariant.body, color: foreground),
              if (description != null && description!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: AppText(
                    description!,
                    variant: AppTextVariant.caption,
                    color: custom.colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Internal leading widget for [AppBigRow] — handles icon, custom widget,
/// and status dot.
class _LeadingWidget extends StatelessWidget {
  final Widget? leading;
  final String? icon;
  final bool dot;
  final Color? dotColor;
  final CustomTheme custom;
  final ValueNotifier<bool> isHovered;

  const _LeadingWidget({
    required this.leading,
    required this.icon,
    required this.dot,
    required this.dotColor,
    required this.custom,
    required this.isHovered,
  });

  @override
  Widget build(BuildContext context) {
    final leadingSize = 32.0;
    final iconSize = 18.0;

    Widget? child;

    if (leading != null) {
      child = SizedBox.square(
        dimension: leadingSize,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: leading,
        ),
      );
    } else if (icon != null) {
      child = Container(
        width: leadingSize,
        height: leadingSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          color: isHovered.value ? custom.colors.hover : custom.colors.panel,
          border: Border.all(color: custom.colors.separator, width: 1),
        ),
        child: Center(
          child: AppIcon(
            icon!,
            size: iconSize,
            color: custom.colors.textSecondary,
          ),
        ),
      );
    }

    if (child == null) return const SizedBox.shrink();

    if (!dot) return child;

    // Status dot overlay
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor ?? custom.colors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: custom.colors.cardBackground, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// AppBigGroup
// ---------------------------------------------------------------------------

/// A labeled card group for [AppBigRow] items, modeled after Electron's
/// `SettingsGroup.vue`.
///
/// Renders a small label and wraps children in a rounded card with a subtle
/// border.
///
/// ```dart
/// AppBigGroup(
///   label: '内置',
///   children: [
///     AppBigRow(name: '默认智能体', ...),
///     AppBigRow(name: '编程助手', ...),
///   ],
/// )
/// ```
class AppBigGroup extends StatelessWidget {
  /// Group label (e.g. "内置", "自定义").
  final String label;

  /// The rows inside this group (typically [AppBigRow]s).
  final List<Widget> children;

  const AppBigGroup({super.key, required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Label ----
        Padding(
          padding: EdgeInsets.only(
            left: custom.spacing.xs + 2,
            bottom: custom.spacing.xs,
          ),
          child: AppText(
            label,
            variant: AppTextVariant.caption,
            color: custom.colors.textSecondary,
          ),
        ),
        // ---- Card container ----
        Container(
          decoration: BoxDecoration(
            color: custom.colors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: custom.colors.border, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0)
                  // Remove duplicate bottom border from previous row
                  // by overlaying a zero-height container
                  const SizedBox.shrink(),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// AppBigList
// ---------------------------------------------------------------------------

/// Outer shell for a settings list page, modeled after Electron's
/// `SettingsList.vue`.
///
/// Provides a header with count + action buttons, a search bar, group slots,
/// and an empty state.
///
/// ```dart
/// AppBigList(
///   count: filteredCount,
///   countLabel: '个智能体',
///   searchTerm: searchQuery,
///   onSearchChanged: (v) => searchQuery = v,
///   searchPlaceholder: '搜索智能体',
///   actions: [
///     AppPrimaryButton(text: '创建智能体', ...),
///   ],
///   emptyState: AppBigEmpty(
///     icon: 'robot',
///     title: '尚未创建智能体',
///     hint: '点击"创建智能体"开始配置',
///   ),
///   children: [
///     AppBigGroup(label: '内置', children: [...]),
///     AppBigGroup(label: '自定义', children: [...]),
///   ],
/// )
/// ```
class AppBigList extends StatelessWidget {
  /// Total item count displayed in the header.
  final int? count;

  /// Label after the count (e.g. "个智能体").
  final String? countLabel;

  /// Whether to show the search bar.
  final bool showSearch;

  /// Current search term value.
  final String searchTerm;

  /// Called when the search term changes.
  final ValueChanged<String>? onSearchChanged;

  /// Placeholder text for the search input.
  final String searchPlaceholder;

  /// Optional action widgets in the header (e.g. a "create" button).
  final List<Widget>? actions;

  /// Groups inside the list (typically [AppBigGroup] widgets).
  final List<Widget>? children;

  /// Widget shown when [count] is 0.
  final Widget? emptyState;

  const AppBigList({
    super.key,
    this.count,
    this.countLabel,
    this.showSearch = false,
    this.searchTerm = '',
    this.onSearchChanged,
    this.searchPlaceholder = '搜索',
    this.actions,
    this.children,
    this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        custom.spacing.sm,
        0,
        custom.spacing.sm,
        custom.spacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Header ----
          if (count != null && actions != null)
            Padding(
              padding: EdgeInsets.only(
                top: custom.spacing.sm,
                bottom: custom.spacing.sm,
                left: 2,
              ),
              child: Row(
                children: [
                  if (count != null) ...[
                    AppText(count.toString(), variant: AppTextVariant.title),
                    if (countLabel != null)
                      Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: AppText(
                          countLabel!,
                          variant: AppTextVariant.caption,
                          color: custom.colors.textSecondary,
                        ),
                      ),
                  ],
                  const Spacer(),
                  if (actions != null)
                    Row(mainAxisSize: MainAxisSize.min, children: actions!),
                ],
              ),
            ),

          // ---- Search ----
          if (showSearch)
            Padding(
              padding: EdgeInsets.only(bottom: custom.spacing.sm),
              child: _SettingsSearchBar(
                value: searchTerm,
                placeholder: searchPlaceholder,
                onChanged: onSearchChanged,
              ),
            ),

          // ---- Groups / Empty ----
          if (children != null && children!.isNotEmpty)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < children!.length; i++) ...[
                  if (i > 0) SizedBox(height: custom.spacing.lg),
                  children![i],
                ],
              ],
            ),
          if (count == 0 && emptyState != null) emptyState!,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppBigEmpty
// ---------------------------------------------------------------------------

/// Default empty state for [AppBigList].
///
/// Shows an icon, a title, and an optional hint text.
///
/// ```dart
/// AppBigEmpty(
///   icon: 'robot',
///   title: '尚未创建智能体',
///   hint: '点击"创建智能体"开始配置',
/// )
/// ```
class AppBigEmpty extends StatelessWidget {
  /// Icon name resolved via [AppIcon].
  final String? icon;

  /// Title text (e.g. "尚未创建智能体").
  final String title;

  /// Optional hint text below the title.
  final String? hint;

  const AppBigEmpty({super.key, this.icon, required this.title, this.hint});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return Container(
      margin: EdgeInsets.only(top: custom.spacing.sm),
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      decoration: BoxDecoration(
        color: custom.colors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: custom.colors.border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Opacity(
                opacity: 0.3,
                child: AppIcon(
                  icon!,
                  size: 36,
                  color: custom.colors.textSecondary,
                ),
              ),
            ),
          AppText(
            title,
            variant: AppTextVariant.body,
            color: custom.colors.textSecondary,
          ),
          if (hint != null && hint!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: AppText(
                hint!,
                variant: AppTextVariant.caption,
                color: custom.colors.textDisabled,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal: SettingsSearchBar
// ---------------------------------------------------------------------------

/// Apple-style pill-shaped search input bar.
class _SettingsSearchBar extends HookWidget {
  final String value;
  final String placeholder;
  final ValueChanged<String>? onChanged;

  const _SettingsSearchBar({
    required this.value,
    required this.placeholder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: value);

    useEffect(() {
      if (controller.text != value) {
        controller.text = value;
      }
      return null;
    }, [value]);

    return AppField(
      controller: controller,
      placeholder: placeholder,
      onChanged: onChanged,
      size: FieldSize.md,
      icon: 'search',
    );
  }
}
