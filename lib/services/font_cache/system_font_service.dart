import 'dart:ffi';
import 'dart:io' show Directory, File, Platform, Process;

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../../utils/font_name_parser.dart';

/// 本机已安装字体信息。
class SystemFontInfo {
  final String family;
  final bool cjk;

  const SystemFontInfo({required this.family, required this.cjk});
}

/// 枚举本机已安装字体。
///
/// 各平台实现：
/// - Windows：注册表 `HKLM\...\Fonts`
/// - macOS：扫描系统字体目录并解析字体文件名称
/// - Linux：`fc-list`（fontconfig）
///
/// Flutter 桌面端会通过系统字体引擎（DirectWrite/CoreText/Skia）按
/// family 名直接解析系统字体，因此这里只需要拿到名字列表，无需加载字体文件。
class SystemFontService {
  SystemFontService._();
  static final instance = SystemFontService._();

  static const _fontsKey =
      r'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts';

  /// macOS 系统字体目录（含用户级）。
  static const _macFontDirs = [
    '/System/Library/Fonts',
    '/System/Library/Fonts/Supplemental',
    '/Library/Fonts',
    '~/Library/Fonts',
  ];

  List<SystemFontInfo>? _cached;

  /// 返回本机已安装字体列表（首次调用后缓存）。
  Future<List<SystemFontInfo>> listFonts() async {
    final cached = _cached;
    if (cached != null) return cached;
    final names = await _enumerateFonts();
    final list = [
      for (final family in names)
        SystemFontInfo(family: family, cjk: isCjkFamily(family)),
    ];
    list.sort(
      (a, b) => a.family.toLowerCase().compareTo(b.family.toLowerCase()),
    );
    _cached = list;
    return list;
  }

  Future<List<String>> _enumerateFonts() async {
    if (Platform.isWindows) return _enumerateWindowsFonts();
    if (Platform.isMacOS) return _enumerateMacFonts();
    if (Platform.isLinux) return _enumerateLinuxFonts();
    return [];
  }

  /// 通过注册表枚举已安装字体名。
  List<String> _enumerateWindowsFonts() {
    final names = <String>{};
    final phk = calloc<Pointer>();
    try {
      final status = RegOpenKeyEx(
        HKEY_LOCAL_MACHINE,
        PCWSTR(_fontsKey.toNativeUtf16()),
        0,
        KEY_READ | KEY_WOW64_64KEY,
        phk,
      );
      if (status != ERROR_SUCCESS) return names.toList();
      final hKey = HKEY(phk.value);

      final valueNameBuf = calloc<Uint16>(512).cast<Utf16>();
      final nameLen = calloc<Uint32>();
      final type = calloc<Uint32>();
      try {
        var index = 0;
        while (true) {
          nameLen.value = 511;
          final rc = RegEnumValue(
            hKey,
            index,
            PWSTR(valueNameBuf),
            nameLen,
            type,
            nullptr,
            nullptr,
          );
          if (rc == ERROR_NO_MORE_ITEMS) break;
          if (rc != ERROR_SUCCESS) {
            index++;
            continue;
          }
          final raw = valueNameBuf.toDartString();
          final family = _cleanFamilyName(raw);
          if (family != null) names.add(family);
          index++;
        }
      } finally {
        RegCloseKey(hKey);
        calloc.free(valueNameBuf);
        calloc.free(nameLen);
        calloc.free(type);
      }
      return names.toList();
    } finally {
      calloc.free(phk);
    }
  }

  /// macOS：扫描系统字体目录，解析每个字体文件的 family 名。
  Future<List<String>> _enumerateMacFonts() async {
    final names = <String>{};
    for (final dirPath in _macFontDirs) {
      final dir = Directory(
        dirPath.replaceFirst('~/', '${Platform.environment['HOME']}/'),
      );
      if (!dir.existsSync()) continue;
      try {
        for (final f in dir.listSync().whereType<File>()) {
          final lower = f.path.toLowerCase();
          if (!lower.endsWith('.ttf') &&
              !lower.endsWith('.otf') &&
              !lower.endsWith('.ttc')) {
            continue;
          }
          try {
            final family = parseFontFamilyName(await f.readAsBytes());
            if (family != null && family.isNotEmpty) names.add(family);
          } catch (_) {
            // 单个文件解析失败不影响其他字体
          }
        }
      } catch (_) {
        // 目录不可读时跳过
      }
    }
    return names.toList();
  }

  /// Linux：调用 `fc-list`（fontconfig）输出 family 名。
  Future<List<String>> _enumerateLinuxFonts() async {
    try {
      final result = await Process.run('fc-list', ['-f', '%{family}\n']);
      if (result.exitCode != 0) return [];
      return parseFcListOutput(result.stdout as String);
    } catch (_) {
      return []; // fc-list 不存在等场景
    }
  }

  /// 解析 `fc-list -f '%{family}\n'` 输出：
  /// 每行可能含多个 family（逗号分隔）与样式（冒号分隔），去重返回。
  static List<String> parseFcListOutput(String output) {
    final names = <String>{};
    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // 去掉样式部分（最后一个冒号后）
      final families = trimmed.split(':').first.trim();
      for (final f in families.split(',')) {
        final name = f.trim();
        if (name.isNotEmpty) names.add(name);
      }
    }
    return names.toList();
  }

  /// 注册表条目名 → family 名。
  ///
  /// 只保留以 `(TrueType)`/`(OpenType)` 结尾的条目（跳过 .fon 位图字体）；
  /// 去掉后缀；`A & B` 形式的联合条目拆开。
  String? _cleanFamilyName(String raw) {
    String? name;
    for (final suffix in [' (TrueType)', ' (OpenType)']) {
      if (raw.endsWith(suffix)) {
        name = raw.substring(0, raw.length - suffix.length);
        break;
      }
    }
    if (name == null) return null; // 位图字体等
    name = name.trim();
    if (name.isEmpty) return null;
    if (name.contains(' & ')) {
      return name.split(' & ').first.trim();
    }
    return name;
  }

  /// 启发式判断字体名是否为中日韩字体（用于「中文」筛选）。
  static bool isCjkFamily(String family) {
    // 名字里直接含 CJK 字符（如「楷体」「明瞭」）
    if (RegExp(
      r'[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uac00-\ud7af]',
    ).hasMatch(family)) {
      return true;
    }
    final lower = family.toLowerCase();
    const keywords = [
      // 常见中文字体名
      'yahei', 'jhenghei', 'dengxian', 'simsun', 'simhei', 'simkai',
      'kaiti', 'fangsong', 'lisu', 'youyuan', 'mingliu', 'pmingliu',
      'wqy', 'wenquanyi', 'source han', 'noto sans sc', 'noto serif sc',
      'noto sans tc', 'noto serif tc', 'lxgw', 'wenkai', 'zcool',
      'mashen', 'ma shan', 'stxihei', 'stheit', 'stkaiti', 'stsong',
      'stzhong', 'stfang', 'stliti', 'stxinwei', 'stcaiyun',
      'fzshusong', 'fzhei', 'fzkai', 'fzfangsong', 'fzshuti', 'fzxingkai',
      'misans', 'mi sans', 'harmonyos', 'harmonyos sans', 'puhuiti',
      'pu hui ti', 'smiley sans', 'alibaba', 'alibaba puhuiti',
      'oppo sans', 'vivo sans', 'honor sans', 'meizu',
      // macOS 中文字体
      'pingfang', 'hiragino', 'songti', 'heiti',
      // 通用 CJK 标记
      'cjk', 'gothic', 'hei', 'song', 'kai', 'fang', 'yuan', 'ming',
    ];
    return keywords.any(lower.contains);
  }
}
