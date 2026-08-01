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
/// - [AppBigSection] — data class for virtualized sectioned lists; used with
///   [AppBigList.sections].
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';
import 'package:agent/widgets/list/app_list.dart';

// ---------------------------------------------------------------------------
// AppBigSection — data class for virtualized sections
// ---------------------------------------------------------------------------

/// A virtualized section inside [AppBigList] rendered via [ListView.builder].
///
/// Each section shows a [label] header followed by [itemCount] items built
/// lazily by [itemBuilder]. The builder receives the index plus [isFirst] and
/// [isLast] flags so it can apply card-aware decoration.
class AppBigSection {
  /// Section header label (e.g. "已配置", "未配置").
  final String label;

  /// Number of items in this section.
  final int itemCount;

  /// Called to build each item.
  ///
  /// [isFirst] is true for the first item in the section,
  /// [isLast] is true for the last item.
  final Widget Function(
    BuildContext context,
    int index, {
    required bool isFirst,
    required bool isLast,
  })
  itemBuilder;

  const AppBigSection({
    required this.label,
    required this.itemCount,
    required this.itemBuilder,
  });
}

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
              AppText(
                name,
                variant: AppTextVariant.body,
                color: foreground,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (description != null && description!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: AppText(
                    description!,
                    variant: AppTextVariant.caption,
                    color: custom.colors.textSecondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
        _CardSurface(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: custom.colors.border, width: 1),
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
/// When [sections] is provided (instead of [children]), the list body renders
/// as a virtualized [ListView.builder] — items are built lazily as the user
/// scrolls. This is the recommended approach for lists with many items.
///
/// ```dart
/// AppBigList(
///   count: filteredCount,
///   countLabel: '个提供商',
///   showSearch: true,
///   searchTerm: searchQuery,
///   onSearchChanged: (v) => searchQuery = v,
///   sections: [
///     AppBigSection(
///       label: '已配置',
///       itemCount: configured.length,
///       itemBuilder: (ctx, i, {isFirst, isLast}) => ...,
///     ),
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
  ///
  /// Pre-built children are rendered eagerly in a [Column]. Prefer [sections]
  /// for large lists.
  final List<Widget>? children;

  /// Virtualized sections rendered lazily via [ListView.builder].
  ///
  /// When provided, [children] is ignored and the list body is virtualized.
  /// The parent must provide bounded height (e.g. via [Expanded] or
  /// [SizedBox]). Set [ContentFrame.scrollable] to false when using this mode.
  final List<AppBigSection>? sections;

  /// Widget shown when [count] is 0 and no [sections] have items.
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
    this.sections,
    this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    // ---- Virtualized path (sections) ----
    if (sections != null && sections!.isNotEmpty) {
      return _buildVirtualized(context, custom);
    }

    // ---- Static path (children) ----
    return _buildStatic(context, custom);
  }

  /// Renders header + search + sectioned virtual list.
  Widget _buildVirtualized(BuildContext context, CustomTheme custom) {
    final totalItems = sections!.fold<int>(0, (s, sec) => s + sec.itemCount);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        custom.spacing.sm,
        0,
        custom.spacing.sm,
        custom.spacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---- Header ----
          if (count != null && actions != null) _buildHeader(custom),

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

          // ---- Virtualized list body ----
          if (totalItems > 0)
            Expanded(child: _VirtualSectionList(sections: sections!))
          else if (emptyState != null)
            Flexible(child: emptyState!),
        ],
      ),
    );
  }

  /// Renders the original Column-based layout (backward compat).
  Widget _buildStatic(BuildContext context, CustomTheme custom) {
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
          if (count != null && actions != null) _buildHeader(custom),

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

  /// Shared header: count label + action buttons.
  Widget _buildHeader(CustomTheme custom) {
    return Padding(
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
    );
  }
}

// ---------------------------------------------------------------------------
// _VirtualSectionList — internal ListView.builder wrapper
// ---------------------------------------------------------------------------

/// Renders [AppBigSection]s as a flat virtualized list with card-style
/// decoration on section items and group headers between sections.
class _VirtualSectionList extends StatelessWidget {
  final List<AppBigSection> sections;

  const _VirtualSectionList({required this.sections});

  /// Flat index count: per section, 1 label + itemCount items.
  int get _flattenedCount {
    int total = 0;
    for (final sec in sections) {
      total += 1 + sec.itemCount;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _flattenedCount,
      itemBuilder: (ctx, flatIndex) => _buildItem(ctx, flatIndex),
    );
  }

  Widget _buildItem(BuildContext context, int flatIndex) {
    final custom = CustomTheme.of(context);

    int cursor = 0;
    for (final sec in sections) {
      // Section label header
      if (cursor == flatIndex) {
        return Padding(
          padding: EdgeInsets.only(
            top: custom.spacing.xs + 2,
            bottom: custom.spacing.xs,
          ),
          child: AppText(
            sec.label,
            variant: AppTextVariant.caption,
            color: custom.colors.textSecondary,
          ),
        );
      }
      cursor++;

      // Items within this section
      if (flatIndex < cursor + sec.itemCount) {
        final itemIndex = flatIndex - cursor;
        return _CardSlot(
          isFirst: itemIndex == 0,
          isLast: itemIndex == sec.itemCount - 1,
          child: sec.itemBuilder(
            context,
            itemIndex,
            isFirst: itemIndex == 0,
            isLast: itemIndex == sec.itemCount - 1,
          ),
        );
      }
      cursor += sec.itemCount;
    }

    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// _CardSlot — per-item card decoration wrapper
// ---------------------------------------------------------------------------

/// Wraps a single item in card-style decoration appropriate for its position.
///
/// The first item in a section gets top-rounded corners and a top border.
/// The last item gets bottom-rounded corners and a bottom border.
/// Solo items (first == last) get all corners rounded.
class _CardSlot extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final Widget child;

  const _CardSlot({
    required this.isFirst,
    required this.isLast,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return _CardSurface(
      borderRadius: BorderRadius.only(
        topLeft: isFirst ? const Radius.circular(12) : Radius.zero,
        topRight: isFirst ? const Radius.circular(12) : Radius.zero,
        bottomLeft: isLast ? const Radius.circular(12) : Radius.zero,
        bottomRight: isLast ? const Radius.circular(12) : Radius.zero,
      ),
      border: Border(
        top: isFirst
            ? BorderSide(color: custom.colors.border)
            : BorderSide.none,
        bottom: isLast
            ? BorderSide(color: custom.colors.border)
            : BorderSide.none,
        left: BorderSide(color: custom.colors.border),
        right: BorderSide(color: custom.colors.border),
      ),
      child: child,
    );
  }
}

/// Card appearance: rounded background + border.
///
/// Uses a three-layer stack so the border is painted on top of the child:
/// hover backgrounds (e.g. [AppBigRow]'s rounded [AppListItem] highlight) are
/// clipped to the card shape by [ClipRRect] and can never cover the border or
/// spill past the rounded corners.
class _CardSurface extends StatelessWidget {
  final BorderRadius borderRadius;
  final Border border;
  final Widget child;

  const _CardSurface({
    required this.borderRadius,
    required this.border,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return Stack(
      fit: StackFit.passthrough,
      children: [
        // 1. Card background (bottom layer)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: custom.colors.cardBackground,
              borderRadius: borderRadius,
            ),
          ),
        ),
        // 2. Content clipped to the rounded card shape
        ClipRRect(borderRadius: borderRadius, child: child),
        // 3. Border overlay (top layer, never covered by hover background)
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: border,
              ),
            ),
          ),
        ),
      ],
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
