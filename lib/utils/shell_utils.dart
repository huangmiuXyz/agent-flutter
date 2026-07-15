import 'dart:io';

/// Resolves the shell executable path.
///
/// If [shell] is non-empty, returns it directly.
/// Otherwise detects an appropriate shell from the environment:
/// - Windows: `pwsh.exe`
/// - Linux/macOS: `$SHELL` env var, falling back to `/bin/zsh` then `/bin/bash`
String resolveShell([String shell = '']) {
  if (shell.isNotEmpty) return shell;
  if (Platform.isWindows) return 'pwsh.exe';
  final envShell = Platform.environment['SHELL'];
  if (envShell != null && envShell.isNotEmpty) return envShell;
  return File('/bin/zsh').existsSync() ? '/bin/zsh' : '/bin/bash';
}

/// Returns a short display label for a shell path (e.g. `pwsh`, `zsh`, `bash`).
String shellLabel(String shell) {
  return resolveShell(
    shell,
  ).split(RegExp(r'[\\/]')).last.replaceAll('.exe', '');
}
