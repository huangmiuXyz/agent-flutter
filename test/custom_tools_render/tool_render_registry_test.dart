import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent/features/chat/custom_tools_render/builtin_tool_renders.dart';
import 'package:agent/features/chat/custom_tools_render/builtin_tool_results.dart';
import 'package:agent/features/chat/custom_tools_render/tool_args_extractor.dart';
import 'package:agent/features/chat/custom_tools_render/tool_render_registry.dart';
import 'package:agent/features/chat/widgets/chat_expandable_part.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/text/code_block_view.dart';

/// 测试宿主：提供主题扩展与固定宽度、松高度约束
/// （对齐消息列表项的真实上下文：宽度紧、高度由内容决定）
Widget wrap(Widget child) => MaterialApp(
  theme: ThemeData(extensions: [CustomTheme.light]),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 400, child: child),
    ),
  ),
);

void main() {
  group('注册表', () {
    // 与 Rust 端 builtin_tools::list_options 的内置工具清单对齐
    test('覆盖全部内置工具，未知工具返回 null', () {
      const builtinTools = [
        'load_skill',
        'apply_patch',
        'read_file',
        'grep',
        'find_path',
        'list_directory',
        'shell_command',
        'spawn_sub_agent',
        'simulated_terminal',
        'terminal_send_input',
      ];
      for (final name in builtinTools) {
        expect(toolRenderSpec(name), isNotNull, reason: '缺少 $name 的渲染');
      }
      expect(toolRenderSpec('mcp__server__tool'), isNull);
      expect(toolRenderSpec(''), isNull);
      expect(toolRenderSpec(null), isNull);
    });

    test('标题从参数提取关键信息', () {
      final spec = toolRenderSpec('read_file')!;
      expect(spec.title(extractToolArgs('{"path": "src/main.rs"}')), '读取文件 src/main.rs');
      // 流式半截 JSON：字符串值保留已到达前缀
      expect(spec.title(extractToolArgs('{"path": "src/ma')), '读取文件 src/ma');
      // 主值未到达：只显示动作词
      expect(spec.title(extractToolArgs('')), '读取文件');
    });

    test('命令类标题只取命令首行', () {
      final spec = toolRenderSpec('shell_command')!;
      expect(
        spec.title(extractToolArgs('{"command": "flutter analyze\nflutter test"}')),
        '执行命令 flutter analyze',
      );
    });

    test('apply_patch 标题固定且标题色为成功色', () {
      final spec = toolRenderSpec('apply_patch')!;
      expect(spec.title(extractToolArgs('{"patch": "*** Begin Patch"}')), '应用补丁');
      expect(spec.titleColor, isNotNull);
    });
  });

  group('参数视图', () {
    testWidgets('read_file 渲染路径与行区间', (tester) async {
      await tester.pumpWidget(
        wrap(
          ReadFileArgsView(
            rawArguments:
                '{"path": "lib/main.dart", "start_line": 10, "end_line": 20}',
          ),
        ),
      );
      expect(find.text('lib/main.dart'), findsOneWidget);
      expect(find.text('行区间 10 - 20'), findsOneWidget);
    });

    testWidgets('grep 渲染正则与限定条件', (tester) async {
      await tester.pumpWidget(
        wrap(
          GrepArgsView(
            rawArguments:
                '{"regex": "TODO", "include_pattern": "**/*.dart", "case_sensitive": true}',
          ),
        ),
      );
      expect(find.text('TODO'), findsOneWidget);
      expect(find.text('文件匹配 **/*.dart'), findsOneWidget);
      expect(find.text('大小写 敏感'), findsOneWidget);
    });

    testWidgets('shell_command 渲染命令代码块与工作目录', (tester) async {
      await tester.pumpWidget(
        wrap(
          ShellCommandArgsView(
            rawArguments: '{"command": "flutter analyze", "workdir": "agent-flutter"}',
            label: 'shell',
          ),
        ),
      );
      expect(find.byType(CodeBlockView), findsOneWidget);
      expect(find.text('flutter analyze'), findsOneWidget);
      expect(find.text('shell'), findsOneWidget);
      expect(find.text('工作目录 agent-flutter'), findsOneWidget);
    });

    testWidgets('spawn_sub_agent 渲染智能体与任务描述', (tester) async {
      await tester.pumpWidget(
        wrap(
          SpawnSubAgentArgsView(
            rawArguments: '{"agent_id": "reviewer", "task": "审查这次改动", "mode": "async"}',
          ),
        ),
      );
      expect(find.text('reviewer'), findsOneWidget);
      expect(find.text('审查这次改动'), findsOneWidget);
      expect(find.text('模式 async'), findsOneWidget);
    });

    testWidgets('流式半截参数渐进显示', (tester) async {
      await tester.pumpWidget(wrap(ReadFileArgsView(rawArguments: '{"path": "lib/ma')));
      expect(find.text('lib/ma'), findsOneWidget);
    });

    testWidgets('主值未到达时不渲染', (tester) async {
      await tester.pumpWidget(wrap(ReadFileArgsView(rawArguments: '')));
      expect(find.byType(ToolMonoValueRow), findsNothing);
    });
  });

  group('结果视图', () {
    testWidgets('shell_command 渲染退出码与终端输出块', (tester) async {
      await tester.pumpWidget(
        wrap(ShellResultView(rawResult: 'exit code: 0\nhello world')),
      );
      expect(find.text('成功'), findsOneWidget);
      expect(find.byType(TerminalOutputBlock), findsOneWidget);
      expect(find.text('hello world'), findsOneWidget);
    });

    testWidgets('shell_command 非零退出码显示退出码，超时显示超时提示', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ShellResultView(
            rawResult:
                'command timed out after 5000 milliseconds\nexit code: 2\nboom',
          ),
        ),
      );
      expect(find.text('退出码 2'), findsOneWidget);
      expect(find.text('超时 5000 ms'), findsOneWidget);
      expect(find.text('boom'), findsOneWidget);
    });

    testWidgets('shell_command 无退出码前缀（报错）回退通用渲染', (tester) async {
      await tester.pumpWidget(
        wrap(ShellResultView(rawResult: '错误：无法执行命令')),
      );
      expect(find.byType(ToolResultTextView), findsOneWidget);
      expect(find.byType(TerminalOutputBlock), findsNothing);
    });

    testWidgets('read_file 渲染文件头、行号与区间起始行号', (tester) async {
      const result =
          '文件: lib/a.dart\n大小: 24 字节 | 行数: 30\n行区间: 10–12\n'
          '----------------------------------------\nvoid a() {}\nvoid b() {}\nvoid c() {}\n'
          '\n[显示第 10–12 行，共 30 行。如需其他区段请再次调用 read_file。]';
      await tester.pumpWidget(
        wrap(
          ReadFileResultView(
            rawArguments: '{"path": "lib/a.dart"}',
            rawResult: result,
          ),
        ),
      );
      expect(find.text('lib/a.dart'), findsOneWidget);
      expect(find.text('显示区间 10 – 12'), findsOneWidget);
      // 行号从区间起点开始
      expect(find.text('10'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('void b() {}'), findsOneWidget);
      // 尾注独立展示
      expect(find.textContaining('显示第 10–12 行'), findsOneWidget);
    });

    testWidgets('read_file 区间越界（正文只有提示）与图片读取回退', (tester) async {
      await tester.pumpWidget(
        wrap(
          ReadFileResultView(
            rawArguments: '{"path": "a.txt"}',
            rawResult:
                '文件: a.txt\n大小: 5 字节 | 行数: 2\n'
                '----------------------------------------\n'
                '[文件只有 2 行，请求的行区间 5–9 超出范围。]',
          ),
        ),
      );
      expect(find.textContaining('超出范围'), findsOneWidget);
      // 提示不应被当作正文行渲染（无行号 1）
      expect(find.text('1'), findsNothing);

      await tester.pumpWidget(
        wrap(
          ReadFileResultView(
            rawArguments: '{"path": "a.png"}',
            rawResult: '[图片已读取] 文件: a.png | 格式: PNG | 大小: 100 字节',
          ),
        ),
      );
      expect(find.byType(ToolResultTextView), findsOneWidget);
    });

    testWidgets('grep 渲染匹配统计与路径:行号: 内容', (tester) async {
      const result =
          '搜索目录: /tmp/proj\n模式: /TODO/（匹配完成）\n'
          '扫描 8 个文本文件（跳过 1 个二进制/非 UTF-8 文件），共 2 处匹配\n'
          '----------------------------------------\n'
          '/tmp/proj/a.dart:3: // TODO fix\n'
          '/tmp/proj/b.dart:7: // TODO later\n';
      await tester.pumpWidget(wrap(GrepResultView(rawResult: result)));
      expect(find.text('匹配 共 2 处'), findsOneWidget);
      expect(find.textContaining('/tmp/proj/a.dart:3'), findsOneWidget);
      expect(find.textContaining('// TODO later'), findsOneWidget);
    });

    testWidgets('list_directory 渲染目录条目与文件大小', (tester) async {
      const result =
          '目录: /tmp/proj\n----------------------------------------\n'
          '子目录（1 个）:\n  src/\n文件（2 个）:\n  main.rs (1.2 KB)\n  README.md\n';
      await tester.pumpWidget(wrap(ListDirResultView(rawResult: result)));
      expect(find.text('目录 /tmp/proj'), findsOneWidget);
      expect(find.text('src/'), findsOneWidget);
      expect(find.text('main.rs (1.2 KB)'), findsOneWidget);
      expect(find.text('README.md'), findsOneWidget);
    });

    testWidgets('apply_patch 渲染操作摘要，报错回退通用渲染', (tester) async {
      await tester.pumpWidget(
        wrap(
          PatchResultView(
            rawResult: '+ added: lib/new.dart\n~ updated: lib/old.dart',
          ),
        ),
      );
      expect(find.text('新增 lib/new.dart'), findsOneWidget);
      expect(find.text('更新 lib/old.dart'), findsOneWidget);

      await tester.pumpWidget(wrap(PatchResultView(rawResult: 'patch 应用失败')));
      expect(find.byType(ToolResultTextView), findsOneWidget);
    });

    testWidgets('spawn_sub_agent 同步完成态解析为标识 + 任务 + 结果', (tester) async {
      await tester.pumpWidget(
        wrap(
          SubAgentResultView(
            rawResult:
                '[子智能体「评审员」已完成 · 会话 sub_1]\n任务：审查改动\n结果：没有问题',
          ),
        ),
      );
      expect(find.textContaining('「评审员」已完成'), findsOneWidget);
      expect(find.text('审查改动'), findsOneWidget);
      expect(find.text('没有问题'), findsOneWidget);
    });

    testWidgets('ChatExpandablePart 结果区由 resultBuilder 接管', (tester) async {
      await tester.pumpWidget(
        wrap(
          ChatExpandablePart(
            content:
                '{"id":"c1","function":{"name":"shell_command","arguments":"{\\"command\\": \\"ls\\"}"}}',
            iconName: 'terminalSquare',
            title: '执行命令 ls',
            titleColor: Colors.black,
            resultContent: 'exit code: 0\nfile a\nfile b',
            resultBuilder: (_, _, result) => ShellResultView(rawResult: result),
            initiallyExpanded: true,
          ),
        ),
      );
      // 参数区 + 自定义结果区同时存在
      expect(find.byType(ShellResultView), findsOneWidget);
      expect(find.text('成功'), findsOneWidget);
      expect(find.text('file a'), findsOneWidget);
    });
  });
}
