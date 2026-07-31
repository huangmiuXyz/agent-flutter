/// Font settings detail page — full font selection list.
///
/// Extracted from the original [DisplaySettingsPage] so that display settings
/// can serve as a form-based overview with breadcrumb navigation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/services/font_cache/font_cache_service.dart';
import 'package:agent/store/setting_store.dart';
import 'package:agent/store/theme_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/list/app_big_list.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 本地捆绑字体（始终可用，无需网络）。
const _kBundledLabel = 'JetBrains Mono';
const _kBundledFamily = 'JetBrainsMono';

/// Google Fonts 中支持 CJK 的字体名称集合。
const _cjkFonts = <String>{
  // ── Noto / Source Han（语言标记 SC/TC/JP/KR/HK）──
  'Noto Sans SC', 'Noto Sans TC', 'Noto Sans JP', 'Noto Sans KR',
  'Noto Sans HK',
  'Noto Serif SC', 'Noto Serif TC', 'Noto Serif JP', 'Noto Serif KR',
  'Noto Serif HK',
  'Noto Sans Mono CJK SC',
  'Source Han Sans SC',
  'Source Han Sans TC',
  'Source Han Sans JP',
  'Source Han Sans KR',
  'Source Han Serif SC',
  'Source Han Serif TC',
  'Source Han Serif JP',
  'Source Han Serif KR',
  'Cactus Classical Serif', 'Chocolate Classical Sans',

  // ── LXGW（霞鹜文楷）──
  'LXGW Marker Gothic', 'LXGW WenKai Mono TC', 'LXGW WenKai TC',

  // ── WDXL Lubrifont / Chiron ──
  'WDXL Lubrifont SC', 'WDXL Lubrifont TC', 'WDXL Lubrifont JP N',
  'Chiron Hei HK',

  // ── 中文风格 ──
  'Ma Shan Zheng', 'ZCOOL XiaoWei', 'ZCOOL QingKe HuangYou',
  'ZCOOL KuaiLe', 'Liu Jian Mao Cao', 'Zhi Mang Xing', 'Long Cang',

  // ── 日文 ──
  'Sawarabi Gothic', 'Sawarabi Mincho',
  'Hina Mincho', 'Klee One',
  'M PLUS 1', 'M PLUS 1 Code', 'M PLUS 1p', 'M PLUS 2', 'M PLUS Rounded 1c',
  'BIZ UDGothic', 'BIZ UDMincho', 'BIZ UDPGothic', 'BIZ UDPMincho',
  'Kosugi', 'Kosugi Maru',
  'Shippori Mincho', 'Shippori Mincho B1',
  'Shippori Antique', 'Shippori Antique B1',
  'Yusei Magic', 'Kiwi Maru', 'New Tegomin',
  'Reggae One', 'Train One', 'DotGothic16',
  'Stick', 'RocknRoll One', 'Rampart One', 'Chokokutai',
  'Kaisei Decol', 'Kaisei HarunoUmi', 'Kaisei Opti', 'Kaisei Tokumin',
  'Zen Old Mincho', 'Zen Antique', 'Zen Antique Soft',
  'Zen Kaku Gothic New', 'Zen Kaku Gothic Antique',
  'Zen Kurenaido', 'Zen Maru Gothic', 'Zen Dots',
  'Yuji Boku', 'Yuji Hentaigana Akari', 'Yuji Hentaigana Akebono',
  'Yuji Mai', 'Yuji Syuku',
  'Dela Gothic One', 'Gothic A1',
  'IBM Plex Sans JP',
  'Cute Font',
  'Noto Serif Hentaigana',

  // ── 韩文 ──
  'Nanum Gothic', 'Nanum Gothic Coding', 'Nanum Myeongjo',
  'Nanum Pen Script', 'Nanum Brush Script',
  'Black Han Sans', 'Do Hyeon', 'Dongle',
  'Gamja Flower', 'Gowun Batang', 'Gowun Dodum',
  'Hahmlet', 'Hi Melody', 'IBM Plex Sans KR',
  'Jua', 'Poor Story', 'Single Day', 'Song Myung',
  'Sunflower',
};

/// Full-screen font selection page.
///
/// Displays all available fonts (bundled, cached, and online) with search
/// and filtering. Replaces the original inline font UI of
/// [DisplaySettingsPage].
class FontSettingsPage extends HookWidget {
  /// Called when the user wants to go back to display settings.
  final VoidCallback onBack;

  const FontSettingsPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final store = ThemeStore.instance;
    final currentFont = useExistingSignal(store.fontFamily);
    final searchTerm = useState('');
    final cachedFonts = useState<List<CachedFontInfo>>([]);
    final showAll = useState(false);
    final cjkOnly = useState(false);
    const int pageSize = 50;

    void rescanCache() {
      FontCacheService.instance.scanCache().then((list) {
        // 页面可能已卸载（例如切换 tab），避免写入已销毁的 ValueNotifier
        if (context.mounted) {
          cachedFonts.value = list;
        }
      });
    }

    useEffect(() {
      rescanCache();
      return null;
    }, []);

    void onSelectFont(String family) {
      store.fontFamily.value = family;
      SettingStore.instance.setFontFamily(family);
      FontCacheService.instance.markSelected(family);
      rescanCache();
    }

    Future<void> onDeleteFont(String family) async {
      await FontCacheService.instance.deleteFont(family);
      rescanCache();
    }

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

    final filteredFonts = useMemoized(() {
      var list = allFonts;
      if (cjkOnly.value) {
        list = list.where((opt) => _cjkFonts.contains(opt['label'])).toList();
      }
      if (searchTerm.value.isNotEmpty) {
        final q = searchTerm.value.toLowerCase();
        list = list.where((opt) {
          return opt['label']!.toLowerCase().contains(q) ||
              opt['family']!.toLowerCase().contains(q);
        }).toList();
      }
      return list;
    }, [searchTerm.value, allFonts, cjkOnly.value]);

    final sections = useMemoized(
      () {
        final bundled = <Map<String, String>>[];
        final cached = <Map<String, String>>[];
        final notCached = <Map<String, String>>[];

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
          final total = notCached.length;
          final shown = notCachedDisplayed.length;
          result.add(
            AppBigSection(
              label: '未下载',
              itemCount: shown + (shown < total ? 1 : 0),
              itemBuilder: (ctx, i, {required isFirst, required isLast}) {
                if (i == shown && shown < total) {
                  return _buildShowAllButton(
                    context,
                    total,
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

    // 过滤后总字体数（含捆绑字体），用于 header 计数
    final bundledShown =
        searchTerm.value.isEmpty ||
        _kBundledLabel.toLowerCase().contains(searchTerm.value.toLowerCase());
    final totalCount = filteredFonts.length + (bundledShown ? 1 : 0);

    // 结构参考 [ModelListPage]：面包屑导航 + AppBigList 内容
    return ContentFrame(
      scrollable: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Breadcrumb ----
          AppBreadcrumb(
            items: [
              AppBreadcrumbItem('设置', onTap: () {}),
              AppBreadcrumbItem('显示设置', onTap: onBack),
              AppBreadcrumbItem('字体设置'),
            ],
          ),
          SizedBox(height: custom.spacing.lg),

          // ---- Content ----
          Expanded(
            child: AppBigList(
              count: totalCount,
              countLabel: '个字体',
              showSearch: true,
              searchTerm: searchTerm.value,
              searchPlaceholder: cjkOnly.value
                  ? '搜索中文字体…'
                  : '搜索 Google Fonts（共 1500+ 种）…',
              onSearchChanged: (v) {
                searchTerm.value = v;
                showAll.value = false;
              },
              actions: [
                _filterChip(context, '全部', !cjkOnly.value, () {
                  cjkOnly.value = false;
                  showAll.value = false;
                }),
                SizedBox(width: custom.spacing.sm),
                _filterChip(context, '中文', cjkOnly.value, () {
                  cjkOnly.value = true;
                  showAll.value = false;
                }),
              ],
              emptyState: AppBigEmpty(
                icon: 'type',
                title: '未找到匹配的字体',
                hint: '试试切换“中文”筛选或清空搜索关键词。',
              ),
              sections: sections,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    BuildContext context,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    final custom = CustomTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: custom.spacing.sm + 4,
          vertical: custom.spacing.xs,
        ),
        decoration: BoxDecoration(
          color: active ? custom.colors.accent : Colors.transparent,
          borderRadius: custom.radii.full,
          border: Border.all(
            color: active ? custom.colors.accent : custom.colors.border,
          ),
        ),
        child: Text(
          label,
          style: custom.typography.styleForSize(
            custom.typography.captionSize,
            active ? custom.colors.onAccent : custom.colors.textPrimary,
          ),
        ),
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
