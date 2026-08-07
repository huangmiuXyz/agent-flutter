import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show FontLoader;
import 'package:path_provider/path_provider.dart';

import '../../utils/font_name_parser.dart';

/// 导入字体文件信息。
class ImportedFontInfo {
  final String family;
  final String filePath;
  final int sizeBytes;

  const ImportedFontInfo({
    required this.family,
    required this.filePath,
    required this.sizeBytes,
  });
}

/// 导入字体管理：复制字体文件到应用数据目录、通过 [FontLoader]
/// 注册到 Flutter 引擎、扫描与删除。
///
/// 字体文件存放在 `<appSupport>/fonts/` 下，命名 `Family.ttf`。
/// 注意：FontLoader 注册后无法注销，删除字体文件后需要重启应用
/// 才会从引擎中移除。
class ImportedFontService {
  ImportedFontService._();
  static final instance = ImportedFontService._();

  final Map<String, File> _imported = {};
  final Set<String> _registered = {};

  /// 启动时调用：扫描导入目录并注册全部字体（幂等）。
  Future<void> loadAll() async {
    try {
      final dir = await _dir();
      for (final f in dir.listSync().whereType<File>()) {
        if (!_isFontFile(f.path)) continue;
        final family = await _familyOf(f) ?? _stem(f.path);
        _imported[family] = f;
        await _register(family, f);
      }
    } catch (_) {
      // 目录不存在等场景静默处理
    }
  }

  /// 扫描导入目录，返回当前已导入字体列表。
  Future<List<ImportedFontInfo>> scan() async {
    _imported.clear();
    final result = <ImportedFontInfo>[];
    try {
      final dir = await _dir();
      for (final f in dir.listSync().whereType<File>()) {
        if (!_isFontFile(f.path)) continue;
        final family = await _familyOf(f) ?? _stem(f.path);
        _imported[family] = f;
        result.add(
          ImportedFontInfo(
            family: family,
            filePath: f.path,
            sizeBytes: f.lengthSync(),
          ),
        );
      }
    } catch (_) {}
    result.sort(
      (a, b) => a.family.toLowerCase().compareTo(b.family.toLowerCase()),
    );
    return result;
  }

  /// 导入字体文件（复制 + 注册）。返回成功导入的 family 名列表。
  Future<List<String>> importFiles(List<String> paths) async {
    final added = <String>[];
    for (final path in paths) {
      final src = File(path);
      if (!src.existsSync() || !_isFontFile(path)) continue;
      final family = await _familyOf(src);
      if (family == null || family.isEmpty) continue;
      final dest = File(
        '${(await _dir()).path}${Platform.pathSeparator}$family.ttf',
      );
      await src.copy(dest.path);
      await _register(family, dest);
      _imported[family] = dest;
      added.add(family);
    }
    return added;
  }

  /// 删除导入的字体文件（FontLoader 注册保留到下次启动）。
  Future<bool> deleteFont(String family) async {
    final f = _imported.remove(family);
    if (f == null) return false;
    try {
      if (f.existsSync()) await f.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 是否为已导入字体。
  bool contains(String family) => _imported.containsKey(family);

  Future<Directory> _dir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}${Platform.pathSeparator}fonts');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  bool _isFontFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.ttf') || lower.endsWith('.otf');
  }

  String _stem(String path) {
    final name = path.contains('/')
        ? path.substring(path.lastIndexOf('/') + 1)
        : path.substring(path.lastIndexOf('\\') + 1);
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  Future<String?> _familyOf(File f) async {
    try {
      final Uint8List bytes = await f.readAsBytes();
      return parseFontFamilyName(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<void> _register(String family, File f) async {
    if (_registered.contains(family)) return;
    _registered.add(family);
    final loader = FontLoader(family);
    loader.addFont(f.readAsBytes().then(ByteData.sublistView));
    await loader.load();
  }
}
