import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 本地捆绑字体标记（不参与缓存管理）。
const String kBundledMarker = 'JetBrainsMono';

/// 字体下载状态。
enum FontCacheStatus { bundled, cached, notCached }

/// 缓存字体文件信息。
class CachedFontInfo {
  final String familyName;
  final String filePath;
  final int sizeBytes;

  CachedFontInfo({
    required this.familyName,
    required this.filePath,
    required this.sizeBytes,
  });
}

/// Google Fonts 缓存管理。
///
/// 缓存文件命名格式：`FamilyName_Variant_Hash.ttf`
/// 例如：`Inter_Regular_400_abc123.ttf`
class FontCacheService {
  FontCacheService._();
  static final instance = FontCacheService._();

  List<CachedFontInfo> _cached = [];

  /// 扫描缓存目录，返回已下载字体列表。
  Future<List<CachedFontInfo>> scanCache() async {
    try {
      final dir = await _cacheDir();

      // 保留内存标记的字体名（磁盘可能尚未写入）
      final memOnly = _cached.where((c) => c.filePath.isEmpty).toList();

      if (!dir.existsSync()) {
        _cached = memOnly;
        return _cached;
      }

      _cached = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.ttf'))
          .map((f) {
            final path = f.path;
            final name = path.contains('/')
                ? path.substring(path.lastIndexOf('/') + 1)
                : path.substring(path.lastIndexOf('\\') + 1);
            // Remove hash suffix (last _hash.ttf)
            final lastUnderscore = name.lastIndexOf('_');
            final prefix = lastUnderscore > 0
                ? name.substring(0, lastUnderscore)
                : name.replaceAll('.ttf', '');
            // Extract family name (before first variant underscore)
            final firstUnderscore = prefix.indexOf('_');
            final familyName = firstUnderscore > 0
                ? prefix.substring(0, firstUnderscore)
                : prefix;
            return CachedFontInfo(
              familyName: familyName,
              filePath: f.path,
              sizeBytes: f.lengthSync(),
            );
          })
          .toList();

      // 合并内存标记（磁盘已有则被真实文件覆盖）
      for (final m in memOnly) {
        if (!_cached.any((c) => c.familyName == m.familyName)) {
          _cached.add(m);
        }
      }

      return _cached;
    } catch (_) {
      _cached = [];
      return _cached;
    }
  }

  /// 将字体标记为已下载（内存标记，不等磁盘写入）。
  void markSelected(String family) {
    final prefix = family.replaceAll(' ', '');
    // 如果磁盘已有记录则不用重复添加
    if (_cached.any((c) => c.familyName == prefix)) return;
    _cached.add(CachedFontInfo(familyName: prefix, filePath: '', sizeBytes: 0));
  }

  /// 查询字体的下载状态。
  FontCacheStatus statusFor(String family) {
    if (family == kBundledMarker) return FontCacheStatus.bundled;
    // 先查内存标记（选中即视为已下载）
    final prefix = family.replaceAll(' ', '');
    return _cached.any((c) => c.familyName == prefix)
        ? FontCacheStatus.cached
        : FontCacheStatus.notCached;
  }

  /// 删除缓存字体文件。
  Future<bool> deleteFont(String family) async {
    try {
      final prefix = family.replaceAll(' ', '');
      final matches = _cached.where((c) => c.familyName == prefix).toList();
      for (final m in matches) {
        if (m.filePath.isNotEmpty) {
          await File(m.filePath).delete();
        }
      }
      _cached.removeWhere((c) => matches.contains(c));
      return matches.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<Directory> _cacheDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory(support.path);
  }
}
