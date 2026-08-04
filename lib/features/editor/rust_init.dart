import 'dart:io';

import 'package:code_forge/code_forge.dart'
    show RustLib;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;

/// 初始化 code_forge 的 rust 运行时（幂等）。
///
/// 优先走标准加载；失败时回退到本地编译产物（`rust/target/release`）。
/// 重复初始化会抛 [StateError]（已初始化），调用方按已就绪处理。
Future<void> ensureRustLibInitialized() async {
  try {
    await RustLib.init();
    return;
  } on StateError {
    return;
  } catch (_) {}

  final libDir = Directory(
    '.patches/code_forge/rust/target/release',
  ).absolute.path;

  String libName;
  if (Platform.isMacOS) {
    libName = 'libcode_forge.dylib';
  } else if (Platform.isWindows) {
    libName = 'code_forge.dll';
  } else if (Platform.isLinux) {
    libName = 'libcode_forge.so';
  } else {
    throw UnsupportedError(
      'Unsupported platform: ${Platform.operatingSystem}',
    );
  }

  final libPath = '$libDir${Platform.pathSeparator}$libName';
  if (!File(libPath).existsSync()) {
    throw FileSystemException('code_forge native library not found', libPath);
  }

  final lib = ExternalLibrary.open(libPath);
  await RustLib.init(externalLibrary: lib);
}
