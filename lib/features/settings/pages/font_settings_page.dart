/// Font settings detail page — full font selection list.
///
/// Extracted from the original [DisplaySettingsPage] so that display settings
/// can serve as a form-based overview with breadcrumb navigation.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/services/font_cache/font_cache_service.dart';
import 'package:agent/services/font_cache/imported_font_service.dart';
import 'package:agent/services/font_cache/system_font_service.dart';
import 'package:agent/store/setting_store.dart';
import 'package:agent/store/theme_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/list/app_big_list.dart';
import 'package:agent/widgets/tab/app_tab_bar.dart';
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
/// Displays all available fonts (bundled, imported, system, cached, and
/// online) with search and filtering. Replaces the original inline font UI of
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
    // 终端专用字体（null = 跟随界面字体）
    final terminalFont = useExistingSignal(store.terminalFontFamily);
    // Markdown 渲染专用字体（null = 跟随界面字体）
    final markdownFont = useExistingSignal(store.markdownFontFamily);
    // 0 = 界面字体，1 = 终端字体，2 = Markdown 字体
    final target = useState(0);
    final searchTerm = useState('');
    final cachedFonts = useState<List<CachedFontInfo>>([]);
    final importedFonts = useState<List<ImportedFontInfo>>([]);
    final systemFonts = useState<List<SystemFontInfo>>([]);
    final showAll = useState(false);
    final cjkOnly = useState(false);
    // 0 = 全部，1 = 本地，2 = 在线
    final activeTab = useState(0);
    const int pageSize = 50;

    void rescanCache() {
      FontCacheService.instance.scanCache().then((list) {
        // 页面可能已卸载（例如切换 tab），避免写入已销毁的 ValueNotifier
        if (context.mounted) {
          cachedFonts.value = list;
        }
      });
    }

    void rescanImported() {
      ImportedFontService.instance.scan().then((list) {
        if (context.mounted) {
          importedFonts.value = list;
        }
      });
    }

    void rescanSystem() {
      SystemFontService.instance.listFonts().then((list) {
        if (context.mounted) {
          systemFonts.value = list;
        }
      });
    }

    useEffect(() {
      rescanCache();
      rescanImported();
      rescanSystem();
      return null;
    }, []);

    void onSelectFont(String family) {
      switch (target.value) {
        case 1:
          store.terminalFontFamily.value = family;
          SettingStore.instance.setTerminalFontFamily(family);
        case 2:
          store.markdownFontFamily.value = family;
          SettingStore.instance.setMarkdownFontFamily(family);
        default:
          store.fontFamily.value = family;
          SettingStore.instance.setFontFamily(family);
      }
      FontCacheService.instance.markSelected(family);
      rescanCache();
    }

    /// 恢复终端/Markdown 字体跟随界面字体（对应目标下点击「跟随界面字体」行）
    void onFollowInterfaceFont() {
      if (target.value == 1) {
        store.terminalFontFamily.value = null;
        SettingStore.instance.setTerminalFontFamily(null);
      } else if (target.value == 2) {
        store.markdownFontFamily.value = null;
        SettingStore.instance.setMarkdownFontFamily(null);
      }
    }

    Future<void> onDeleteFont(String family) async {
      if (ImportedFontService.instance.contains(family)) {
        // 删除导入字体：文件删除立即生效，FontLoader 注册保留到下次启动
        await ImportedFontService.instance.deleteFont(family);
        if (store.fontFamily.value == family) {
          store.fontFamily.value = kDefaultFontFamily;
          SettingStore.instance.setFontFamily(kDefaultFontFamily);
        }
        if (store.terminalFontFamily.value == family) {
          store.terminalFontFamily.value = null;
          SettingStore.instance.setTerminalFontFamily(null);
        }
        if (store.markdownFontFamily.value == family) {
          store.markdownFontFamily.value = null;
          SettingStore.instance.setMarkdownFontFamily(null);
        }
        rescanImported();
      } else {
        await FontCacheService.instance.deleteFont(family);
        rescanCache();
      }
    }

    Future<void> onImportFont() async {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
        dialogTitle: '导入字体文件',
      );
      final paths = files
          .map((f) => f.path)
          .whereType<String>()
          .toList();
      if (paths.isEmpty) return;
      final added = await ImportedFontService.instance.importFiles(paths);
      if (added.isNotEmpty) {
        rescanImported();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: AppText('已导入 ${added.length} 个字体'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
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

    // 导入字体：搜索/筛选后按 family 名排序
    final filteredImported = useMemoized(() {
      var list = importedFonts.value;
      if (cjkOnly.value) {
        list = list
            .where((f) => SystemFontService.isCjkFamily(f.family))
            .toList();
      }
      if (searchTerm.value.isNotEmpty) {
        final q = searchTerm.value.toLowerCase();
        list = list.where((f) => f.family.toLowerCase().contains(q)).toList();
      }
      return list;
    }, [importedFonts.value, searchTerm.value, cjkOnly.value]);

    // 系统字体：默认只显示中日韩字体；搜索时显示全部匹配
    final filteredSystem = useMemoized(() {
      var list = systemFonts.value;
      if (searchTerm.value.isNotEmpty) {
        final q = searchTerm.value.toLowerCase();
        list = list.where((f) => f.family.toLowerCase().contains(q)).toList();
      } else {
        list = list.where((f) => f.cjk).toList();
      }
      return list;
    }, [systemFonts.value, searchTerm.value]);

    // 当前目标的有效字体（列表选中判断用；未设置时为空 → 无选中行）
    final effectiveCurrentFont = switch (target.value) {
      1 => terminalFont.value ?? '',
      2 => markdownFont.value ?? '',
      _ => currentFont.value,
    };

    // 当前目标实际生效的字体（子目标未单独设置时 = 界面字体）
    final actualFont = switch (target.value) {
      1 => terminalFont.value ?? currentFont.value,
      2 => markdownFont.value ?? currentFont.value,
      _ => currentFont.value,
    };

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
        // 置顶「当前使用中」分组：展示当前目标实际生效的字体（信息行，不可点击）
        result.add(
          AppBigSection(
            label: '当前使用中',
            itemCount: 1,
            itemBuilder: (ctx, i, {required isFirst, required isLast}) {
              final desc = switch (target.value) {
                1 => terminalFont.value == null
                    ? '终端字体（跟随界面字体）'
                    : '终端字体',
                2 => markdownFont.value == null
                    ? 'Markdown 字体（跟随界面字体）'
                    : 'Markdown 字体',
                _ => '界面字体',
              };
              return AppBigRow(
                name: actualFont,
                description: desc,
                dot: true,
              );
            },
          ),
        );
        // 终端/Markdown 字体目标：最前面插入「跟随界面字体」行（未设置时选中）
        final isSubTarget = target.value == 1 || target.value == 2;
        if (isSubTarget) {
          final following = target.value == 1
              ? terminalFont.value == null
              : markdownFont.value == null;
          result.add(
            AppBigSection(
              label: '跟随界面字体',
              itemCount: 1,
              itemBuilder: (ctx, i, {required isFirst, required isLast}) =>
                  AppBigRow(
                    name: '跟随界面字体',
                    description: following
                        ? '当前使用中（默认，与界面字体一致）'
                        : '点击后${target.value == 1 ? '终端' : 'Markdown'}恢复使用界面字体',
                    dot: following,
                    clickable: true,
                    onTap: onFollowInterfaceFont,
                  ),
            ),
          );
        }
        // 本地类分区：全部 / 本地 tab 显示（在线 tab 隐藏）
        final showLocalSections = activeTab.value != 2;
        // 在线类分区：全部 / 在线 tab 显示（本地 tab 隐藏）
        final showOnlineSections = activeTab.value != 1;

        if (showLocalSections && bundled.isNotEmpty) {
          result.add(
            AppBigSection(
              label: '本地捆绑',
              itemCount: bundled.length,
              itemBuilder: (ctx, i, {required isFirst, required isLast}) =>
                  _buildRow(
                    bundled[i],
                    effectiveCurrentFont,
                    FontCacheStatus.bundled,
                    null,
                    onSelectFont,
                  ),
            ),
          );
        }
        if (showLocalSections && filteredImported.isNotEmpty) {
          result.add(
            AppBigSection(
              label: '已导入',
              itemCount: filteredImported.length,
              itemBuilder: (ctx, i, {required isFirst, required isLast}) {
                final f = filteredImported[i];
                return _buildRow(
                  {'label': f.family, 'family': f.family},
                  effectiveCurrentFont,
                  FontCacheStatus.notCached,
                  () => onDeleteFont(f.family),
                  onSelectFont,
                  description: '本地导入字体',
                );
              },
            ),
          );
        }
        if (showLocalSections && filteredSystem.isNotEmpty) {
          result.add(
            AppBigSection(
              label: '系统字体',
              itemCount: filteredSystem.length,
              itemBuilder: (ctx, i, {required isFirst, required isLast}) {
                final f = filteredSystem[i];
                return _buildRow(
                  {'label': f.family, 'family': f.family},
                  effectiveCurrentFont,
                  FontCacheStatus.notCached,
                  null,
                  onSelectFont,
                  description: '本机已安装字体',
                );
              },
            ),
          );
        }
        if (showOnlineSections && cached.isNotEmpty) {
          result.add(
            AppBigSection(
              label: '已下载',
              itemCount: cached.length,
              itemBuilder: (ctx, i, {required isFirst, required isLast}) =>
                  _buildRow(
                    cached[i],
                    effectiveCurrentFont,
                    FontCacheStatus.cached,
                    () => onDeleteFont(cached[i]['family']!),
                    onSelectFont,
                  ),
            ),
          );
        }
        if (showOnlineSections && notCachedDisplayed.isNotEmpty) {
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
                  effectiveCurrentFont,
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
        filteredImported,
        filteredSystem,
        currentFont.value,
        terminalFont.value,
        markdownFont.value,
        actualFont,
        target.value,
        cachedFonts.value,
        searchTerm.value,
        showAll.value,
        activeTab.value,
      ],
    );

    // 过滤后总字体数（含捆绑字体），用于 header 计数
    final bundledShown =
        searchTerm.value.isEmpty ||
        _kBundledLabel.toLowerCase().contains(searchTerm.value.toLowerCase());
    final tab = activeTab.value;
    final totalCount =
        1 + // 「当前使用中」常驻分组
        (tab == 2
            ? 0
            : (bundledShown ? 1 : 0) +
                  filteredImported.length +
                  filteredSystem.length) +
        (tab == 1 ? 0 : filteredFonts.length) +
        // 终端/Markdown 字体目标多一行「跟随界面字体」
        ((target.value == 1 || target.value == 2) ? 1 : 0);

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

          // ---- 目标：界面字体 / 终端字体 / Markdown 字体 ----
          AppTabBar(
            tabs: const ['界面字体', '终端字体', 'Markdown 字体'],
            activeIndex: target.value,
            onChanged: (i) => target.value = i,
            size: TabBarSize.md,
          ),
          SizedBox(height: custom.spacing.md),

          // ---- 来源分类 Tab ----
          AppTabBar(
            tabs: const ['全部', '本地', '在线'],
            activeIndex: activeTab.value,
            onChanged: (i) => activeTab.value = i,
            size: TabBarSize.md,
          ),
          SizedBox(height: custom.spacing.md),

          // ---- Content ----
          Expanded(
            child: AppBigList(
              count: totalCount,
              countLabel: '个字体',
              showSearch: true,
              searchTerm: searchTerm.value,
              searchPlaceholder: cjkOnly.value
                  ? '搜索中文字体…'
                  : (tab == 1
                        ? '搜索本地字体（系统 + 导入）…'
                        : '搜索 Google Fonts（共 1500+ 种）…'),
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
                SizedBox(width: custom.spacing.sm),
                AppIconButton(
                  icon: 'filePlus',
                  tooltip: '导入字体',
                  onPressed: onImportFont,
                ),
              ],
              emptyState: AppBigEmpty(
                icon: 'type',
                title: '未找到匹配的字体',
                hint: '试试切换“中文”筛选、清空搜索关键词，或导入本地字体文件。',
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
        child: AppText(
          label,
          variant: AppTextVariant.caption,
          color: active ? custom.colors.onAccent : custom.colors.textPrimary,
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
    void Function(String) onSelectFont, {
    String? description,
  }) {
    final family = opt['family']!;
    final label = opt['label']!;
    final isSelected = family == currentFont;

    final effectiveDescription = isSelected
        ? '当前使用中'
        : description ??
              switch (status) {
                FontCacheStatus.bundled => '本地捆绑，无需网络',
                FontCacheStatus.cached => '已下载到本地缓存',
                FontCacheStatus.notCached => '需联网下载',
              };

    return AppBigRow(
      name: label,
      description: effectiveDescription,
      dot: isSelected,
      muted: !isSelected && status == FontCacheStatus.notCached,
      clickable: true,
      onTap: () => onSelectFont(family),
      actions: [
        if (onDelete != null) AppIconButton(icon: 'trash', onPressed: onDelete),
      ],
    );
  }
}
