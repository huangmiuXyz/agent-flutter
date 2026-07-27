/// 文件扩展名到语言模式与 LSP 服务器的映射。
library;

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:code_forge/code_forge.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart' as hl_c;
import 'package:re_highlight/languages/clojure.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/dockerfile.dart';
import 'package:re_highlight/languages/elixir.dart';
import 'package:re_highlight/languages/fsharp.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/haskell.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/lua.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/nix.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/plaintext.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';

/// 语言配置
class EditorLanguageConfig {
  final Mode mode;
  final Future<LspConfig?> Function(String filePath, String workspacePath)?
  lspFactory;

  const EditorLanguageConfig({required this.mode, this.lspFactory});
}

/// Windows 上 Dart 的 Process.start 不解析 PATHEXT（.cmd 等），
/// 需要显式通过 cmd /c 来启动 npm 安装的命令。
List<String> _resolveExec(String cmd) {
  if (!Platform.isWindows) return [cmd];
  // .cmd 文件无法被 Dart 直接启动，用 cmd /c 包装
  return ['cmd', '/c', cmd];
}

/// 创建一个 LSP 配置工厂。
/// 自动处理 Windows 上 .cmd 文件的启动问题。
Future<LspConfig> lsp({
  required String executable,
  List<String>? args,
  required String workspacePath,
  required String languageId,
  Map<String, dynamic> initializationOptions = const {},
  Map<String, dynamic> workspaceConfiguration = const {},
  bool disableWarning = false,
  bool disableError = false,
}) => LspStdioConfig.start(
  executable: _resolveExec(executable).first,
  args: [
    if (_resolveExec(executable).length > 1)
      ..._resolveExec(executable).skip(1),
    // ignore: use_null_aware_elements
    if (args != null) ...args,
  ],
  workspacePath: workspacePath,
  languageId: languageId,
  initializationOptions: initializationOptions,
  workspaceConfiguration: workspaceConfiguration,
  disableWarning: disableWarning,
  disableError: disableError,
);

final _languageMap = <String, EditorLanguageConfig>{
  // ═══════════════════════════════════════════
  // Rust
  // ═══════════════════════════════════════════
  'rs': EditorLanguageConfig(
    mode: langRust,
    lspFactory: (f, w) => lsp(
      executable: 'rust-analyzer',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'rust',
    ),
  ),

  // ═══════════════════════════════════════════
  // Dart / Flutter
  // ═══════════════════════════════════════════
  'dart': EditorLanguageConfig(
    mode: langDart,
    lspFactory: (f, w) => lsp(
      executable: 'dart',
      args: ['language-server', '--protocol=lsp'],
      workspacePath: w,
      languageId: 'dart',
    ),
  ),

  // ═══════════════════════════════════════════
  // Python
  // ═══════════════════════════════════════════
  'py': EditorLanguageConfig(
    mode: langPython,
    lspFactory: (f, w) => lsp(
      executable: 'pyright-langserver',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'python',
    ),
  ),
  'pyi': EditorLanguageConfig(
    mode: langPython,
    lspFactory: (f, w) => lsp(
      executable: 'pyright-langserver',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'python',
    ),
  ),

  // ═══════════════════════════════════════════
  // TypeScript / JavaScript
  // ═══════════════════════════════════════════
  'ts': EditorLanguageConfig(
    mode: langTypescript,
    lspFactory: (f, w) => lsp(
      executable: 'typescript-language-server',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'typescript',
    ),
  ),
  'tsx': EditorLanguageConfig(
    mode: langTypescript,
    lspFactory: (f, w) => lsp(
      executable: 'typescript-language-server',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'typescript',
    ),
  ),
  'mts': EditorLanguageConfig(
    mode: langTypescript,
    lspFactory: (f, w) => lsp(
      executable: 'typescript-language-server',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'typescript',
    ),
  ),
  'cts': EditorLanguageConfig(
    mode: langTypescript,
    lspFactory: (f, w) => lsp(
      executable: 'typescript-language-server',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'typescript',
    ),
  ),
  'js': EditorLanguageConfig(
    mode: langJavascript,
    lspFactory: (f, w) => lsp(
      executable: 'typescript-language-server',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'javascript',
    ),
  ),
  'jsx': EditorLanguageConfig(
    mode: langJavascript,
    lspFactory: (f, w) => lsp(
      executable: 'typescript-language-server',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'javascript',
    ),
  ),
  'mjs': EditorLanguageConfig(
    mode: langJavascript,
    lspFactory: (f, w) => lsp(
      executable: 'typescript-language-server',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'javascript',
    ),
  ),
  'cjs': EditorLanguageConfig(
    mode: langJavascript,
    lspFactory: (f, w) => lsp(
      executable: 'typescript-language-server',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'javascript',
    ),
  ),

  // ═══════════════════════════════════════════
  // Go
  // ═══════════════════════════════════════════
  'go': EditorLanguageConfig(
    mode: langGo,
    lspFactory: (f, w) =>
        lsp(executable: 'gopls', args: [], workspacePath: w, languageId: 'go'),
  ),

  // ═══════════════════════════════════════════
  // Java
  // ═══════════════════════════════════════════
  'java': EditorLanguageConfig(
    mode: langJava,
    lspFactory: (f, w) => lsp(
      executable: 'java',
      args: [
        '-jar',
        // 需要先下载 jdtls 语言服务器
        // 参考 opencode 的 JDTLS 实现
      ],
      workspacePath: w,
      languageId: 'java',
      initializationOptions: {'extendedClientCapabilities': {}},
    ),
  ),

  // ═══════════════════════════════════════════
  // C / C++
  // ═══════════════════════════════════════════
  'c': EditorLanguageConfig(
    mode: hl_c.langC,
    lspFactory: (f, w) => lsp(
      executable: 'clangd',
      args: ['--background-index', '--clang-tidy'],
      workspacePath: w,
      languageId: 'c',
    ),
  ),
  'h': EditorLanguageConfig(
    mode: hl_c.langC,
    lspFactory: (f, w) => lsp(
      executable: 'clangd',
      args: ['--background-index', '--clang-tidy'],
      workspacePath: w,
      languageId: 'c',
    ),
  ),
  'cpp': EditorLanguageConfig(
    mode: langCpp,
    lspFactory: (f, w) => lsp(
      executable: 'clangd',
      args: ['--background-index', '--clang-tidy'],
      workspacePath: w,
      languageId: 'cpp',
    ),
  ),
  'cc': EditorLanguageConfig(
    mode: langCpp,
    lspFactory: (f, w) => lsp(
      executable: 'clangd',
      args: ['--background-index', '--clang-tidy'],
      workspacePath: w,
      languageId: 'cpp',
    ),
  ),
  'cxx': EditorLanguageConfig(
    mode: langCpp,
    lspFactory: (f, w) => lsp(
      executable: 'clangd',
      args: ['--background-index', '--clang-tidy'],
      workspacePath: w,
      languageId: 'cpp',
    ),
  ),
  'hpp': EditorLanguageConfig(
    mode: langCpp,
    lspFactory: (f, w) => lsp(
      executable: 'clangd',
      args: ['--background-index', '--clang-tidy'],
      workspacePath: w,
      languageId: 'cpp',
    ),
  ),

  // ═══════════════════════════════════════════
  // C#
  // ═══════════════════════════════════════════
  'cs': EditorLanguageConfig(
    mode: langCsharp,
    lspFactory: (f, w) => lsp(
      executable: 'roslyn-language-server',
      args: ['--stdio', '--autoLoadProjects'],
      workspacePath: w,
      languageId: 'csharp',
    ),
  ),
  'csx': EditorLanguageConfig(
    mode: langCsharp,
    lspFactory: (f, w) => lsp(
      executable: 'roslyn-language-server',
      args: ['--stdio', '--autoLoadProjects'],
      workspacePath: w,
      languageId: 'csharp',
    ),
  ),

  // ═══════════════════════════════════════════
  // F#
  // ═══════════════════════════════════════════
  'fs': EditorLanguageConfig(
    mode: langFsharp,
    lspFactory: (f, w) => lsp(
      executable: 'fsautocomplete',
      args: [],
      workspacePath: w,
      languageId: 'fsharp',
    ),
  ),
  'fsx': EditorLanguageConfig(
    mode: langFsharp,
    lspFactory: (f, w) => lsp(
      executable: 'fsautocomplete',
      args: [],
      workspacePath: w,
      languageId: 'fsharp',
    ),
  ),
  'fsi': EditorLanguageConfig(
    mode: langFsharp,
    lspFactory: (f, w) => lsp(
      executable: 'fsautocomplete',
      args: [],
      workspacePath: w,
      languageId: 'fsharp',
    ),
  ),

  // ═══════════════════════════════════════════
  // Ruby
  // ═══════════════════════════════════════════
  'rb': EditorLanguageConfig(
    mode: langRuby,
    lspFactory: (f, w) => lsp(
      executable: 'rubocop',
      args: ['--lsp'],
      workspacePath: w,
      languageId: 'ruby',
    ),
  ),
  'rake': EditorLanguageConfig(
    mode: langRuby,
    lspFactory: (f, w) => lsp(
      executable: 'rubocop',
      args: ['--lsp'],
      workspacePath: w,
      languageId: 'ruby',
    ),
  ),
  'gemspec': EditorLanguageConfig(
    mode: langRuby,
    lspFactory: (f, w) => lsp(
      executable: 'rubocop',
      args: ['--lsp'],
      workspacePath: w,
      languageId: 'ruby',
    ),
  ),

  // ═══════════════════════════════════════════
  // Swift
  // ═══════════════════════════════════════════
  'swift': EditorLanguageConfig(
    mode: langSwift,
    lspFactory: (f, w) => lsp(
      executable: 'sourcekit-lsp',
      args: [],
      workspacePath: w,
      languageId: 'swift',
    ),
  ),

  // ═══════════════════════════════════════════
  // Kotlin
  // ═══════════════════════════════════════════
  'kt': EditorLanguageConfig(
    mode: langKotlin,
    lspFactory: (f, w) => lsp(
      executable: 'kotlin-lsp',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'kotlin',
    ),
  ),
  'kts': EditorLanguageConfig(
    mode: langKotlin,
    lspFactory: (f, w) => lsp(
      executable: 'kotlin-lsp',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'kotlin',
    ),
  ),

  // ═══════════════════════════════════════════
  // PHP
  // ═══════════════════════════════════════════
  'php': EditorLanguageConfig(
    mode: langPhp,
    lspFactory: (f, w) => lsp(
      executable: 'intelephense',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'php',
    ),
  ),

  // ═══════════════════════════════════════════
  // Lua
  // ═══════════════════════════════════════════
  'lua': EditorLanguageConfig(
    mode: langLua,
    lspFactory: (f, w) => lsp(
      executable: 'lua-language-server',
      args: [],
      workspacePath: w,
      languageId: 'lua',
    ),
  ),

  // ═══════════════════════════════════════════
  // Zig
  // ═══════════════════════════════════════════
  'zig': EditorLanguageConfig(
    mode: langPlaintext,
    lspFactory: (f, w) =>
        lsp(executable: 'zls', args: [], workspacePath: w, languageId: 'zig'),
  ),
  'zon': EditorLanguageConfig(
    mode: langPlaintext,
    lspFactory: (f, w) =>
        lsp(executable: 'zls', args: [], workspacePath: w, languageId: 'zig'),
  ),

  // ═══════════════════════════════════════════
  // Haskell
  // ═══════════════════════════════════════════
  'hs': EditorLanguageConfig(
    mode: langHaskell,
    lspFactory: (f, w) => lsp(
      executable: 'haskell-language-server-wrapper',
      args: ['--lsp'],
      workspacePath: w,
      languageId: 'haskell',
    ),
  ),
  'lhs': EditorLanguageConfig(
    mode: langHaskell,
    lspFactory: (f, w) => lsp(
      executable: 'haskell-language-server-wrapper',
      args: ['--lsp'],
      workspacePath: w,
      languageId: 'haskell',
    ),
  ),

  // ═══════════════════════════════════════════
  // Elixir
  // ═══════════════════════════════════════════
  'ex': EditorLanguageConfig(
    mode: langElixir,
    lspFactory: (f, w) => lsp(
      executable: 'elixir-ls',
      args: [],
      workspacePath: w,
      languageId: 'elixir',
    ),
  ),
  'exs': EditorLanguageConfig(
    mode: langElixir,
    lspFactory: (f, w) => lsp(
      executable: 'elixir-ls',
      args: [],
      workspacePath: w,
      languageId: 'elixir',
    ),
  ),

  // ═══════════════════════════════════════════
  // Clojure
  // ═══════════════════════════════════════════
  'clj': EditorLanguageConfig(
    mode: langClojure,
    lspFactory: (f, w) => lsp(
      executable: 'clojure-lsp',
      args: ['listen'],
      workspacePath: w,
      languageId: 'clojure',
    ),
  ),
  'cljs': EditorLanguageConfig(
    mode: langClojure,
    lspFactory: (f, w) => lsp(
      executable: 'clojure-lsp',
      args: ['listen'],
      workspacePath: w,
      languageId: 'clojure',
    ),
  ),
  'cljc': EditorLanguageConfig(
    mode: langClojure,
    lspFactory: (f, w) => lsp(
      executable: 'clojure-lsp',
      args: ['listen'],
      workspacePath: w,
      languageId: 'clojure',
    ),
  ),
  'edn': EditorLanguageConfig(
    mode: langClojure,
    lspFactory: (f, w) => lsp(
      executable: 'clojure-lsp',
      args: ['listen'],
      workspacePath: w,
      languageId: 'clojure',
    ),
  ),

  // ═══════════════════════════════════════════
  // Nix
  // ═══════════════════════════════════════════
  'nix': EditorLanguageConfig(
    mode: langNix,
    lspFactory: (f, w) =>
        lsp(executable: 'nixd', args: [], workspacePath: w, languageId: 'nix'),
  ),

  // ═══════════════════════════════════════════
  // Gleam
  // ═══════════════════════════════════════════
  'gleam': EditorLanguageConfig(
    mode: langPlaintext,
    lspFactory: (f, w) => lsp(
      executable: 'gleam',
      args: ['lsp'],
      workspacePath: w,
      languageId: 'gleam',
    ),
  ),

  // ═══════════════════════════════════════════
  // Svelte
  // ═══════════════════════════════════════════
  'svelte': EditorLanguageConfig(
    mode: langXml,
    lspFactory: (f, w) => lsp(
      executable: 'svelteserver',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'svelte',
    ),
  ),

  // ═══════════════════════════════════════════
  // Vue
  // ═══════════════════════════════════════════
  'vue': EditorLanguageConfig(
    mode: langXml,
    lspFactory: (f, w) => lsp(
      executable: 'vue-language-server',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'vue',
    ),
  ),

  // ═══════════════════════════════════════════
  // Astro
  // ═══════════════════════════════════════════
  'astro': EditorLanguageConfig(
    mode: langXml,
    lspFactory: (f, w) => lsp(
      executable: 'astro-ls',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'astro',
    ),
  ),

  // ═══════════════════════════════════════════
  // Dockerfile
  // ═══════════════════════════════════════════
  'dockerfile': EditorLanguageConfig(
    mode: langDockerfile,
    lspFactory: (f, w) => lsp(
      executable: 'docker-langserver',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'dockerfile',
    ),
  ),

  // ═══════════════════════════════════════════
  // Terraform
  // ═══════════════════════════════════════════
  'tf': EditorLanguageConfig(
    mode: hl_c.langC,
    lspFactory: (f, w) => lsp(
      executable: 'terraform-ls',
      args: ['serve'],
      workspacePath: w,
      languageId: 'terraform',
    ),
  ),
  'tfvars': EditorLanguageConfig(
    mode: hl_c.langC,
    lspFactory: (f, w) => lsp(
      executable: 'terraform-ls',
      args: ['serve'],
      workspacePath: w,
      languageId: 'terraform',
    ),
  ),

  // ═══════════════════════════════════════════
  // Prisma
  // ═══════════════════════════════════════════
  'prisma': EditorLanguageConfig(
    mode: hl_c.langC,
    lspFactory: (f, w) => lsp(
      executable: 'prisma',
      args: ['language-server'],
      workspacePath: w,
      languageId: 'prisma',
    ),
  ),

  // ═══════════════════════════════════════════
  // YAML (with LSP)
  // ═══════════════════════════════════════════
  'yaml': EditorLanguageConfig(
    mode: langYaml,
    lspFactory: (f, w) => lsp(
      executable: 'yaml-language-server',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'yaml',
    ),
  ),
  'yml': EditorLanguageConfig(
    mode: langYaml,
    lspFactory: (f, w) => lsp(
      executable: 'yaml-language-server',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'yaml',
    ),
  ),

  // ═══════════════════════════════════════════
  // Bash / Shell (with LSP)
  // ═══════════════════════════════════════════
  'sh': EditorLanguageConfig(
    mode: langBash,
    lspFactory: (f, w) => lsp(
      executable: 'bash-language-server',
      args: ['start'],
      workspacePath: w,
      languageId: 'shellscript',
    ),
  ),
  'bash': EditorLanguageConfig(
    mode: langBash,
    lspFactory: (f, w) => lsp(
      executable: 'bash-language-server',
      args: ['start'],
      workspacePath: w,
      languageId: 'shellscript',
    ),
  ),

  // ═══════════════════════════════════════════
  // OCaml
  // ═══════════════════════════════════════════
  'ml': EditorLanguageConfig(
    mode: hl_c.langC,
    lspFactory: (f, w) => lsp(
      executable: 'ocamllsp',
      args: [],
      workspacePath: w,
      languageId: 'ocaml',
    ),
  ),
  'mli': EditorLanguageConfig(
    mode: hl_c.langC,
    lspFactory: (f, w) => lsp(
      executable: 'ocamllsp',
      args: [],
      workspacePath: w,
      languageId: 'ocaml',
    ),
  ),

  // ═══════════════════════════════════════════
  // LaTeX
  // ═══════════════════════════════════════════
  'tex': EditorLanguageConfig(
    mode: hl_c.langC,
    lspFactory: (f, w) => lsp(
      executable: 'texlab',
      args: [],
      workspacePath: w,
      languageId: 'latex',
    ),
  ),
  'bib': EditorLanguageConfig(
    mode: hl_c.langC,
    lspFactory: (f, w) => lsp(
      executable: 'texlab',
      args: [],
      workspacePath: w,
      languageId: 'bibtex',
    ),
  ),

  // ═══════════════════════════════════════════
  // Typst
  // ═══════════════════════════════════════════
  'typ': EditorLanguageConfig(
    mode: hl_c.langC,
    lspFactory: (f, w) => lsp(
      executable: 'tinymist',
      args: [],
      workspacePath: w,
      languageId: 'typst',
    ),
  ),
  'typc': EditorLanguageConfig(
    mode: hl_c.langC,
    lspFactory: (f, w) => lsp(
      executable: 'tinymist',
      args: [],
      workspacePath: w,
      languageId: 'typst',
    ),
  ),

  // ═══════════════════════════════════════════
  // SQL / 纯语法高亮（无需 LSP）
  // ═══════════════════════════════════════════
  'json': EditorLanguageConfig(
    mode: langJson,
    lspFactory: (f, w) => lsp(
      executable: 'vscode-json-languageserver',
      args: ['--stdio'],
      workspacePath: w,
      languageId: 'json',
    ),
  ),
  'md': EditorLanguageConfig(mode: langMarkdown),
  'markdown': EditorLanguageConfig(mode: langMarkdown),
  'sql': EditorLanguageConfig(mode: langSql),
  'xml': EditorLanguageConfig(mode: langXml),
  'html': EditorLanguageConfig(mode: langXml),
  'htm': EditorLanguageConfig(mode: langXml),
  'css': EditorLanguageConfig(mode: langCss),
};

/// 根据文件路径获取语言配置。
EditorLanguageConfig? configFor(String filePath) {
  final ext = filePath.split('.').last.toLowerCase();
  return _languageMap[ext];
}

/// 尝试启动 LSP 服务器（失败时仅打印日志，不抛异常）。
Future<LspConfig?> tryStartLsp(String filePath) async {
  final config = configFor(filePath);
  if (config?.lspFactory == null) {
    debugPrint('LSP: $filePath -> 未配置 LSP');
    return null;
  }

  final workspacePath = Directory(filePath).parent.path;
  try {
    final lsp = await config!.lspFactory!(filePath, workspacePath);
    debugPrint('LSP: $filePath -> ✅ 已启动');
    return lsp;
  } catch (e) {
    stderr.writeln('LSP: $filePath -> ❌ 启动失败: $e');
    debugPrint('LSP: $filePath -> ❌ 启动失败: $e');
    return null;
  }
}
