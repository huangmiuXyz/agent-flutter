import 'dart:io';

void main() {
  final windir = Platform.environment['windir'] ?? r'C:\Windows';
  final dirs = [
    '$windir/fonts/',
    '${Platform.environment['USERPROFILE'] ?? ''}/AppData/Local/Microsoft/Windows/Fonts/',
  ];
  for (final dir in dirs) {
    if (!Directory(dir).existsSync()) {
      stdout.writeln('跳过(不存在): $dir');
      continue;
    }
    final files = Directory(dir).listSync().whereType<File>().toList();
    int ttf = 0, otf = 0, ttc = 0, other = 0;
    final cjkTtf = <String>[];
    final cjkTtc = <String>[];
    for (final f in files) {
      final name = f.path.toLowerCase();
      if (name.endsWith('.ttf')) {
        ttf++;
        if (RegExp(
          r'sim|hei|song|kai|fang|yahei|msyh|ming|gothic|sc|tc|jp|kr|cjk',
        ).hasMatch(f.path.toLowerCase())) {
          cjkTtf.add(f.path.split(RegExp(r'[\\/]')).last);
        }
      } else if (name.endsWith('.otf')) {
        otf++;
      } else if (name.endsWith('.ttc')) {
        ttc++;
        if (RegExp(
          r'sim|hei|song|kai|fang|yahei|msyh|ming|gothic|sc|tc|jp|kr|cjk',
        ).hasMatch(f.path.toLowerCase())) {
          cjkTtc.add(f.path.split(RegExp(r'[\\/]')).last);
        }
      } else {
        other++;
      }
    }
    stdout.writeln('== $dir');
    stdout.writeln('   ttf=$ttf otf=$otf ttc=$ttc 其他=$other');
    stdout.writeln('   疑似中文 ttf: ${cjkTtf.join(', ')}');
    stdout.writeln('   疑似中文 ttc: ${cjkTtc.join(', ')}');
  }
}
