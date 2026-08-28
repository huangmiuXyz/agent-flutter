/// 移动端工作目录导入服务（M0：SAF 选择 → 副本导入应用工作目录）。
///
/// Android 上 Rust 文件工具基于 `std::fs`，无法读 `content://` SAF URI；
/// `file_picker.getDirectoryPath` 把 tree URI 转成 `/storage/emulated/0/...`
/// 形式路径，应用通常也无权直接读取（scoped storage）。
///
/// M0 方案：
/// - 尝试用 dart:io 读取所选目录（应用可访问的目录可用），
///   递归复制到应用工作目录下 `imported/<目录名>`（增量）
/// - 读取失败（权限拒绝）→ 返回 null，调用方提示用户
/// - 目录级 SAF 直读（DocumentFile + ContentResolver / MethodChannel）属 M1
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'package:agent/utils/platform_dirs.dart';

class MobileWorkDirService {
  MobileWorkDirService._();

  static final instance = MobileWorkDirService._();

  /// 应用工作目录根（导入副本的父目录）。
  String get workspaceRoot => defaultMobileWorkDir();

  /// SAF 选择目录并导入副本。
  ///
  /// 返回导入后的工作目录路径；用户取消或目录不可读时返回 null。
  Future<String?> pickAndImport() async {
    final src = await FilePicker.getDirectoryPath();
    if (src == null || src.isEmpty) return null;

    final srcDir = Directory(src);
    try {
      if (!srcDir.existsSync()) return null;
      // 权限校验：无权列举（Android scoped storage 常态）直接失败
      srcDir.listSync();
    } catch (_) {
      return null;
    }

    final dest = Directory(p.join(workspaceRoot, 'imported', p.basename(src)));
    try {
      await _copyDir(srcDir, dest);
    } catch (_) {
      return null;
    }
    return dest.path;
  }

  /// 递归复制目录（增量：目标已存在的同名文件跳过）。
  Future<void> _copyDir(Directory src, Directory dest) async {
    await dest.create(recursive: true);
    await for (final entity in src.list()) {
      if (entity is Directory) {
        await _copyDir(entity, Directory(p.join(dest.path, p.basename(entity.path))));
      } else if (entity is File) {
        final target = File(p.join(dest.path, p.basename(entity.path)));
        if (target.existsSync()) continue;
        await target.writeAsBytes(await entity.readAsBytes());
      }
    }
  }
}
