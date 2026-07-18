import 'dart:io';

String? _cachedDefaultShell;

/// Resolves the shell executable path.
///
/// If [shell] is non-empty, returns it directly.
/// Otherwise detects an appropriate shell from the environment:
/// - Windows: `pwsh.exe`
/// - Linux/macOS: `$SHELL` env var, falling back to `/bin/zsh` then `/bin/bash`
///
/// The auto-detected result is cached after the first call to avoid repeated
/// synchronous filesystem checks.
String resolveShell([String shell = '']) {
  if (shell.isNotEmpty) return shell;
  if (_cachedDefaultShell != null) return _cachedDefaultShell!;
  if (Platform.isWindows) {
    _cachedDefaultShell = 'pwsh.exe';
    return _cachedDefaultShell!;
  }
  final envShell = Platform.environment['SHELL'];
  if (envShell != null && envShell.isNotEmpty) {
    _cachedDefaultShell = envShell;
    return _cachedDefaultShell!;
  }
  _cachedDefaultShell = File('/bin/zsh').existsSync()
      ? '/bin/zsh'
      : '/bin/bash';
  return _cachedDefaultShell!;
}

/// Returns a short display label for a shell path (e.g. `pwsh`, `zsh`, `bash`).
String shellLabel(String shell) {
  return shell.split(RegExp(r'[\/]')).last.replaceAll('.exe', '');
}
