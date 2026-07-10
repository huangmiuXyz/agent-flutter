import 'dart:io';
import 'package:path/path.dart' as p;

// ignore_for_file: avoid_print

/// Applies all *.patch files in this directory to their corresponding
/// packages in pub cache.
///
/// Naming: `<package>+<version>.patch` or just `<package>.patch`.
Future<void> main() async {
  final dir = Directory(_scriptDir);
  final patches = _listPatchFiles(dir);

  if (patches.isEmpty) {
    print('No patch files found in ${dir.path}');
    return;
  }

  for (final patchFile in patches) {
    final pkgId = _resolvePackageId(dir, patchFile);
    if (pkgId == null) {
      print('Skipping: ${p.relative(patchFile.path, from: dir.path)}');
      continue;
    }

    final (name, version) = pkgId;
    final pkgDir = _findPackage(name, version);
    if (pkgDir == null) {
      print('Skipping $name: package not found in pub cache.');
      continue;
    }

    await _applyPatch(pkgDir, patchFile);
  }
}

List<File> _listPatchFiles(Directory dir) {
  final result = <File>[];
  for (final entry in dir.listSync()) {
    if (entry is File && entry.path.endsWith('.patch')) {
      result.add(entry);
    } else if (entry is Directory) {
      result.addAll(_listPatchFiles(entry));
    }
  }
  return result;
}

typedef _PkgInfo = (String name, String? version);

/// Extracts `(package, version)` from file's relative path to [scriptDir].
///
/// For nested files, the closest directory to [scriptDir] names the package.
///
/// Examples:
///   patch/kterm+1.5.1.patch           → (kterm, 1.5.1)
///   patch/kterm.patch                  → (kterm, null)
///   patch/kterm+1.5.1/fix1.patch       → (kterm, 1.5.1)
///   patch/kterm+1.5.1/sub/fix1.patch   → (kterm, 1.5.1)
_PkgInfo? _resolvePackageId(Directory scriptDir, File patchFile) {
  final rel = p.relative(patchFile.path, from: scriptDir.path);
  final segments = p.split(rel);

  // Flat: patch/<name>.patch → parse from filename
  if (segments.length == 1) {
    final base = p.basenameWithoutExtension(segments[0]);
    return _splitNameVersion(base);
  }

  // Nested: use the first directory name as package id
  return _splitNameVersion(segments[0]);
}

/// Splits "kterm+1.5.1" into ("kterm", "1.5.1") or "kterm" into ("kterm", null).
_PkgInfo? _splitNameVersion(String input) {
  if (input.isEmpty) return null;
  final plus = input.indexOf('+');
  if (plus == -1) return (input, null);
  return (input.substring(0, plus), input.substring(plus + 1));
}

Future<void> _applyPatch(Directory pkgDir, File patchFile) async {
  // Try git apply first
  final git = Platform.isWindows ? 'git.exe' : 'git';
  final pkgParent = pkgDir.parent;
  final dirName = pkgDir.path.split(separator).last;
  final result = await Process.run(git, [
    'apply',
    '--directory', dirName,
    '--whitespace=nowarn',
    patchFile.path,
  ], workingDirectory: pkgParent.path);

  if (result.exitCode == 0) {
    print('Applied: $patchFile -> $pkgDir');
    return;
  }

  // Fallback: upgrade _applyManually to handle full unified diffs
  _applyManuallyFull(pkgDir, patchFile);
}

void _applyManuallyFull(Directory pkgDir, File patchFile) {
  final patchLines = patchFile.readAsLinesSync();

  // Find target file path
  String? targetPath;
  for (final line in patchLines) {
    if (line.startsWith('--- a/')) {
      targetPath = line.substring(6);
      break;
    }
  }
  if (targetPath == null || targetPath!.isEmpty) {
    stderr.writeln('Failed to parse target path from: ${patchFile.path}');
    return;
  }

  final target = File('${pkgDir.path}$separator$targetPath');
  if (!target.existsSync()) {
    stderr.writeln('Target not found: ${target.path}');
    return;
  }

  var content = target.readAsStringSync();
  bool anyApplied = false;

  // Parse and apply each hunk
  for (int i = 0; i < patchLines.length; i++) {
    if (!patchLines[i].startsWith('@@')) continue;

    // Collect hunk body lines
    final hunkLines = <String>[];
    i++;
    while (i < patchLines.length) {
      final hl = patchLines[i];
      if (hl.startsWith('@@')) { i--; break; }
      if (hl.startsWith('--- ') || hl.startsWith('+++ ')) { i--; break; }
      if (hl.isEmpty) { /* skip empty lines in patch */ }
      hunkLines.add(hl);
      i++;
    }

    if (hunkLines.isEmpty) continue;

    // Build "old block" (context + removed) and "new block" (context + added)
    final oldBlock = <String>[];
    final newBlock = <String>[];
    for (final hl in hunkLines) {
      if (hl.isEmpty) { oldBlock.add(''); newBlock.add(''); continue; }
      final prefix = hl[0];
      final rest = hl.length > 1 ? hl.substring(1) : '';
      if (prefix == ' ' || prefix == '-') {
        oldBlock.add(rest);
      }
      if (prefix == ' ' || prefix == '+') {
        newBlock.add(rest);
      }
    }

    final oldText = oldBlock.join('\n');
    final newText = newBlock.join('\n');

    if (content.contains(newText)) {
      // Already applied
      continue;
    }

    if (!content.contains(oldText)) {
      stderr.writeln('Pattern mismatch in ${patchFile.path} for $targetPath');
      return;
    }

    content = content.replaceFirst(oldText, newText);
    anyApplied = true;
  }

  if (!anyApplied) {
    print('Already patched: ${patchFile.path} -> ${target.path}');
    return;
  }

  target.writeAsStringSync(content, flush: true);
  print('Applied: ${patchFile.path} -> ${target.path}');
}

String get separator => Platform.pathSeparator;

String get _scriptDir {
  final script = Platform.script.toFilePath();
  return script.substring(0, script.lastIndexOf(separator));
}

String _pubCacheDir() {
  final env = Platform.environment;
  final cache = env['PUB_CACHE'];
  if (cache != null) return cache;

  final localAppData = env['LOCALAPPDATA'];
  if (localAppData != null) {
    final path = '$localAppData${separator}Pub${separator}Cache';
    if (Directory(path).existsSync()) return path;
  }

  final home = env['USERPROFILE'] ?? env['HOME'];
  if (home == null) return '${separator}tmp';

  return Platform.isWindows
      ? '$home${separator}AppData${separator}Local${separator}Pub${separator}Cache'
      : '$home$separator.pub-cache';
}

Directory? _findPackage(String name, String? version) {
  final hosted = Directory('${_pubCacheDir()}${separator}hosted${separator}pub.dev');
  if (!hosted.existsSync()) return null;

  // Version-specific match
  if (version != null) {
    final dir = Directory('${hosted.path}$separator$name-$version');
    if (dir.existsSync()) return dir;
    return null;
  }

  // Any version
  return hosted.listSync().whereType<Directory>().firstWhere(
    (d) {
      final dirName = d.path.split(separator).last;
      return dirName.startsWith('$name-');
    },
    orElse: () => throw Error(),
  );
}
