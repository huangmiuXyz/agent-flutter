import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/services/font_cache/font_cache_service.dart';
import 'package:agent/store/setting_store.dart';
import 'package:agent/store/theme_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/list/app_big_list.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 本地捆绑字体（始终可用，无需网络）。
const _kBundledLabel = 'JetBrains Mono';
const _kBundledFamily = 'JetBrainsMono';

class DisplaySettingsPage extends HookWidget {
  const DisplaySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final store = ThemeStore.instance;
    final currentFont = useExistingSignal(store.fontFamily);
    final searchTerm = useState('');
    final cachedFonts = useState<List<CachedFontInfo>>([]);
    final showAll = useState(false);
    const int pageSize = 50;

    void rescanCache() {
      FontCacheService.instance.scanCache().then((list) {
        cachedFonts.value = list;
      });
    }

    // Scan font cache on mount
    useEffect(() {
      rescanCache();
      return null;
    }, []);

    // 选中字体
    void onSelectFont(String family) {
      store.fontFamily.value = family;
      SettingStore.instance.setFontFamily(family);
      FontCacheService.instance.markSelected(family);
      rescanCache();
    }

    // 删除缓存
    Future<void> onDeleteFont(String family) async {
      await FontCacheService.instance.deleteFont(family);
      rescanCache();
    }

    // 从 GoogleFonts.asMap() 获取所有字体
    final allFonts = useMemoized(() {
      final map = GoogleFonts.asMap();
      final entries = <Map<String, String>>[];
      for (final name in map.keys) {
        if (name == 'JetBrains Mono') continue;
        entries.add({'label': name, 'family': name});
      }
      entries.sort((a, b) => a['label']!.compareTo(b['label']!));
      return entries;
    }, []);

    // 按搜索词过滤
    final filteredFonts = useMemoized(() {
      if (searchTerm.value.isEmpty) return allFonts;
      final q = searchTerm.value.toLowerCase();
      return allFonts.where((opt) {
        return opt['label']!.toLowerCase().contains(q) ||
            opt['family']!.toLowerCase().contains(q);
      }).toList();
    }, [searchTerm.value, allFonts]);

    // 分组（未下载区段默认只显示前 pageSize 个）
    final sections = useMemoized(
      () {
        final bundled = <Map<String, String>>[];
        final cached = <Map<String, String>>[];
        final notCached = <Map<String, String>>[];

        // 始终把 JetBrainsMono 放最前面
        final bundledOpt = {'label': _kBundledLabel, 'family': _kBundledFamily};
        if (searchTerm.value.isEmpty ||
            _kBundledLabel.toLowerCase().contains(
              searchTerm.value.toLowerCase(),
            )) {
          bundled.add(bundledOpt);
        }

        for (final opt in filteredFonts) {
          final family = opt['family']!;
          final status = FontCacheService.instance.statusFor(family);
          if (status == FontCacheStatus.cached) {
            cached.add(opt);
          } else {
            notCached.add(opt);
          }
        }

        // 未搜索时截断未下载列表
        final notCachedDisplayed = searchTerm.value.isNotEmpty || showAll.value
            ? notCached
            : notCached.take(pageSize).toList();

        final result = <AppBigSection>[];
        if (bundled.isNotEmpty) {
          result.add(
            AppBigSection(
              label: '本地捆绑',
              itemCount: bundled.length,
              itemBuilder: (ctx, i, {required isFirst, required isLast}) =>
                  _buildRow(
                    bundled[i],
                    currentFont.value,
                    FontCacheStatus.bundled,
                    null,
                    onSelectFont,
                  ),
            ),
          );
        }
        if (cached.isNotEmpty) {
          result.add(
            AppBigSection(
              label: '已下载',
              itemCount: cached.length,
              itemBuilder: (ctx, i, {required isFirst, required isLast}) =>
                  _buildRow(
                    cached[i],
                    currentFont.value,
                    FontCacheStatus.cached,
                    () => onDeleteFont(cached[i]['family']!),
                    onSelectFont,
                  ),
            ),
          );
        }
        if (notCachedDisplayed.isNotEmpty) {
          result.add(
            AppBigSection(
              label: '未下载',
              itemCount:
                  notCachedDisplayed.length +
                  (notCachedDisplayed.length < notCached.length ? 1 : 0),
              itemBuilder: (ctx, i, {required isFirst, required isLast}) {
                // 最后一项：显示"显示全部"按钮
                if (i == notCachedDisplayed.length &&
                    notCachedDisplayed.length < notCached.length) {
                  return _buildShowAllButton(
                    context,
                    notCached.length,
                    () => showAll.value = true,
                  );
                }
                return _buildRow(
                  notCachedDisplayed[i],
                  currentFont.value,
                  FontCacheStatus.notCached,
                  null,
                  onSelectFont,
                );
              },
            ),
          );
        }
        return result;
      },
      [
        filteredFonts,
        currentFont.value,
        cachedFonts.value,
        searchTerm.value,
        showAll.value,
      ],
    );

    final totalCount = allFonts.length + 1;

    return Padding(
      padding: EdgeInsets.all(custom.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '显示设置',
            style: custom.typography.styleForSize(
              custom.typography.titleSize,
              custom.colors.textPrimary,
              weight: FontWeight.w600,
            ),
          ),
          SizedBox(height: custom.spacing.lg),
          Expanded(
            child: AppBigList(
              showSearch: true,
              searchTerm: searchTerm.value,
              searchPlaceholder: '搜索 Google Fonts（共 1500+ 种）…',
              onSearchChanged: (v) {
                searchTerm.value = v;
                showAll.value = false;
              },
              count: totalCount,
              sections: sections,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowAllButton(
    BuildContext context,
    int total,
    VoidCallback onTap,
  ) {
    final custom = CustomTheme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: custom.spacing.sm,
        vertical: custom.spacing.sm,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            AppText(
              '显示全部 $total 个字体',
              variant: AppTextVariant.body,
              color: custom.colors.accent,
            ),
            SizedBox(width: custom.spacing.xs),
            Icon(Icons.expand_more, size: 16, color: custom.colors.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    Map<String, String> opt,
    String currentFont,
    FontCacheStatus status,
    VoidCallback? onDelete,
    void Function(String) onSelectFont,
  ) {
    final family = opt['family']!;
    final label = opt['label']!;
    final isSelected = family == currentFont;

    final description = isSelected
        ? '当前使用中'
        : switch (status) {
            FontCacheStatus.bundled => '本地捆绑，无需网络',
            FontCacheStatus.cached => '已下载到本地缓存',
            FontCacheStatus.notCached => '需联网下载',
          };

    return AppBigRow(
      name: label,
      description: description,
      dot: isSelected,
      muted: !isSelected && status == FontCacheStatus.notCached,
      clickable: true,
      onTap: () => onSelectFont(family),
      actions: [
        if (status == FontCacheStatus.cached && onDelete != null)
          AppIconButton(icon: 'trash', onPressed: onDelete),
      ],
    );
  }
}
