/// 图片文件管理 — 上传的图片统一复制到 app 数据目录的 `File/` 下，
/// DB 与 UI 只保存/引用文件名，不落 base64。
library;

import 'dart:io';

import 'package:nanoid/nanoid.dart';
import 'package:path/path.dart' as p;

import 'package:agent/store/config_store.dart';

/// 导入后的图片：复制路径 + 存储文件名 + 用户选择时的原始文件名
class ImportedImage {
  /// `File/` 目录下的绝对路径（发送/读文件用）
  final String path;

  /// `File/` 目录下的存储文件名（如 img_xxx.png，DB 读取文件用）
  final String storedName;

  /// 用户选择图片时的原始文件名（显示/文本引用用）
  final String displayName;

  ImportedImage({
    required this.path,
    required this.storedName,
    required this.displayName,
  });
}

class ImageStore {
  static final instance = ImageStore._();
  ImageStore._();

  /// 图片存放目录：DB 父目录下的 `File/`
  /// （dev: ../agent-flutter-cli/data/File/，打包: .../agent/data/File/）
  String get imagesDir {
    final dbPath = ConfigStore.instance.dbPath;
    return p.join(p.dirname(dbPath), 'File');
  }

  /// 把选中的图片复制进 `File/` 目录，生成唯一文件名，返回导入信息。
  Future<ImportedImage> importImage(String srcPath) async {
    final dir = Directory(imagesDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final ext = p.extension(srcPath);
    final storedName = 'img_${nanoid(16)}$ext';
    final dest = p.join(imagesDir, storedName);
    await File(srcPath).copy(dest);
    return ImportedImage(
      path: dest,
      storedName: storedName,
      displayName: p.basename(srcPath),
    );
  }

  /// 按文件名解析完整路径
  String resolvePath(String filename) => p.join(imagesDir, filename);

  /// 文件存在性缓存：UI 每次重建都会同步 stat 一遍图片文件。
  /// 文件名随机生成且文件一旦写入不会被删除，缓存结果即可。
  final Map<String, bool> _existsCache = {};

  /// 文件名对应的图片文件是否存在
  bool exists(String filename) {
    return _existsCache.putIfAbsent(
      filename,
      () => File(resolvePath(filename)).existsSync(),
    );
  }
}
