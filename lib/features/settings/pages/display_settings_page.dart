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

/// Google Fonts 中支持 CJK 的字体名称集合（从 google_fonts 包数据中提取）。
/// 包括中文（简/繁/港）、日文、韩文。
const _cjkFonts = <String>{
  // ── Noto / Source Han 系列 ──
  'Noto Sans SC', 'Noto Sans TC', 'Noto Sans JP', 'Noto Sans KR',
  'Noto Serif SC', 'Noto Serif TC', 'Noto Serif JP', 'Noto Serif KR',
  'Noto Sans HK', 'Noto Serif HK',
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

  // ── LXGW（霞鹜文楷）系列 ──
  'LXGW Marker Gothic', 'LXGW WenKai Mono TC', 'LXGW WenKai TC',

  // ── WDXL / Chiron（昭源）系列 ──
  'WDXL Lubrifont SC', 'WDXL Lubrifont TC',
  'Chiron Hei HK',

  // ── 中文手写/风格字体 ──
  'Ma Shan Zheng', 'ZCOOL XiaoWei', 'ZCOOL QingKe HuangYou',
  'ZCOOL KuaiLe', 'Liu Jian Mao Cao', 'Zhi Mang Xing', 'Long Cang',

  // ── 日文字体 ──
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
  'WDXL Lubrifont JP N',
  'Noto Serif Hentaigana',

  // ── 韩文字体 ──
  'Nanum Gothic', 'Nanum Gothic Coding', 'Nanum Myeongjo',
  'Nanum Pen Script', 'Nanum Brush Script',
  'Black Han Sans', 'Do Hyeon', 'Dongle',
  'Gamja Flower', 'Gowun Batang', 'Gowun Dodum',
  'Hahmlet', 'Hi Melody', 'IBM Plex Sans KR',
  'Jua', 'Poor Story', 'Single Day', 'Song Myung',
  'Sunflower',
};

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
    final cjkOnly = useState(false);
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

    // 按搜索词 + 中文筛选过滤
    final filteredFonts = useMemoized(() {
      var list = allFonts;
      // 中文筛选
      if (cjkOnly.value) {
        list = list.where((opt) => _cjkFonts.contains(opt['label'])).toList();
      }
      // 搜索词
      if (searchTerm.value.isNotEmpty) {
        final q = searchTerm.value.toLowerCase();
        list = list.where((opt) {
          return opt['label']!.toLowerCase().contains(q) ||
              opt['family']!.toLowerCase().contains(q);
        }).toList();
      }
      return list;
    }, [searchTerm.value, allFonts, cjkOnly.value]);

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
          const AppText('显示设置', variant: AppTextVariant.title),
          SizedBox(height: custom.spacing.lg),
          // 筛选按钮
          Row(
            children: [
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
          ),
          SizedBox(height: custom.spacing.sm),
          Expanded(
            child: AppBigList(
              showSearch: true,
              searchTerm: searchTerm.value,
              searchPlaceholder: cjkOnly.value
                  ? '搜索中文字体…'
                  : '搜索 Google Fonts（共 1500+ 种）…',
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
