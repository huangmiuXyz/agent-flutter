import 'dart:io';
import 'dart:typed_data';

import 'package:agent/services/font_cache/system_font_service.dart';
import 'package:agent/utils/font_name_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseFontFamilyName', () {
    late Uint8List jetbrainsMono;

    setUpAll(() async {
      // 本地捆绑字体文件，family 名应为 "JetBrains Mono"
      final file = File('assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf');
      jetbrainsMono = await file.readAsBytes();
    });

    test('解析捆绑字体 family 名', () {
      final name = parseFontFamilyName(jetbrainsMono);
      expect(name, 'JetBrains Mono');
    });

    test('解析 TTC 集合字体（微软雅黑）', () async {
      final file = File(r'C:\Windows\Fonts\msyh.ttc');
      if (!file.existsSync()) {
        markTestSkipped('本机无 msyh.ttc');
        return;
      }
      final name = parseFontFamilyName(await file.readAsBytes());
      expect(name, 'Microsoft YaHei');
    });

    test('非法数据返回 null', () {
      expect(parseFontFamilyName(Uint8List.fromList([1, 2, 3])), isNull);
      expect(parseFontFamilyName(Uint8List(0)), isNull);
    });
  });

  group('SystemFontService.parseFcListOutput', () {
    test('解析 fc-list 输出', () {
      const output =
          '''Noto Sans CJK SC,Noto Sans CJK TC:style=Regular\nDejaVu Sans:style=Book\nNoto Sans CJK SC\n''';
      final names = SystemFontService.parseFcListOutput(output);
      expect(names, contains('Noto Sans CJK SC'));
      expect(names, contains('Noto Sans CJK TC'));
      expect(names, contains('DejaVu Sans'));
    });

    test('空输出返回空列表', () {
      expect(SystemFontService.parseFcListOutput(''), isEmpty);
    });
  });

  group('SystemFontService.isCjkFamily', () {
    test('CJK 启发式判断', () {
      expect(SystemFontService.isCjkFamily('Microsoft YaHei'), isTrue);
      expect(SystemFontService.isCjkFamily('SimSun'), isTrue);
      expect(SystemFontService.isCjkFamily('KaiTi'), isTrue);
      expect(SystemFontService.isCjkFamily('MiSans'), isTrue);
      expect(SystemFontService.isCjkFamily('楷体'), isTrue);
      expect(SystemFontService.isCjkFamily('Noto Sans SC'), isTrue);
      expect(SystemFontService.isCjkFamily('HarmonyOS Sans SC'), isTrue);
      expect(SystemFontService.isCjkFamily('PingFang SC'), isTrue);
      expect(SystemFontService.isCjkFamily('Songti SC'), isTrue);
      expect(SystemFontService.isCjkFamily('Hiragino Sans GB'), isTrue);
      expect(SystemFontService.isCjkFamily('Arial'), isFalse);
      expect(SystemFontService.isCjkFamily('Consolas'), isFalse);
      expect(SystemFontService.isCjkFamily('Segoe UI'), isFalse);
    });
  });

  group('SystemFontService.listFonts', () {
    test('Windows 上能枚举到系统字体', () async {
      final fonts = await SystemFontService.instance.listFonts();
      if (Platform.isWindows) {
        expect(fonts, isNotEmpty);
        // Windows 中文系统至少应有微软雅黑
        expect(
          fonts.any(
            (f) => f.family.contains('YaHei') || f.family.contains('SimSun'),
          ),
          isTrue,
        );
      } else {
        expect(fonts, isEmpty);
      }
    });
  });
}
