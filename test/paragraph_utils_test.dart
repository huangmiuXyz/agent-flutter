import 'package:flutter_test/flutter_test.dart';

import 'package:agent/widgets/text/paragraph_utils.dart';

void main() {
  group('stripExitCodeLine', () {
    test('剥离开头的 exit code 行（\\n 结尾）', () {
      expect(
        stripExitCodeLine('exit code: 0\n    Directory: E:\\code\n'),
        '    Directory: E:\\code\n',
      );
    });

    test('剥离开头的 exit code 行（\\r\\n 结尾，Windows 输出）', () {
      expect(
        stripExitCodeLine('exit code: 3\r\noutput line\r\n'),
        'output line\r\n',
      );
    });

    test('支持负退出码（超时合成码也是正数，但保留负数兼容）', () {
      expect(stripExitCodeLine('exit code: -1\nx'), 'x');
    });

    test('无前缀时原样返回', () {
      const text = 'hello\nworld';
      expect(stripExitCodeLine(text), text);
    });

    test('exit code 不在开头时不剥离', () {
      const text = 'some output\nexit code: 0\n';
      expect(stripExitCodeLine(text), text);
    });

    test('剥离后为空字符串（仅前缀）', () {
      expect(stripExitCodeLine('exit code: 0\n'), '');
    });
  });
}
