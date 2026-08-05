import 'package:flutter/material.dart';

import 'scenarios/ai_chat.dart';
import 'scenarios/comparison.dart';
import 'scenarios/custom_code.dart';
import 'scenarios/latex.dart';
import 'scenarios/longform.dart';
import 'scenarios/theming.dart';

void main() {
  runApp(const StreamdownExampleApp());
}

class StreamdownExampleApp extends StatelessWidget {
  const StreamdownExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'streamdown — examples',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const scenarios = <_Scenario>[
    _Scenario(
      title: '1. Comparison demo',
      subtitle: 'Same stream rendered by flutter_markdown vs streamdown.',
      icon: Icons.compare_arrows,
      builder: ComparisonScreen.new,
    ),
    _Scenario(
      title: '2. AI chat simulator',
      subtitle: 'Mocked LLM stream — drop your own provider in.',
      icon: Icons.chat_bubble_outline,
      builder: AiChatScreen.new,
    ),
    _Scenario(
      title: '3. Syntax theme gallery',
      subtitle: 'Three SyntaxThemes side-by-side.',
      icon: Icons.palette_outlined,
      builder: ThemingScreen.new,
    ),
    _Scenario(
      title: '4. Custom code block builder',
      subtitle: 'Replace the default with your own widget.',
      icon: Icons.code,
      builder: CustomCodeScreen.new,
    ),
    _Scenario(
      title: '5. Long-form article',
      subtitle: 'Static render of a multi-section markdown doc.',
      icon: Icons.article_outlined,
      builder: LongformScreen.new,
    ),
    _Scenario(
      title: '6. LaTeX math',
      subtitle: 'Inline and block math via flutter_math_fork.',
      icon: Icons.functions,
      builder: LatexScreen.new,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('streamdown — examples'),
      ),
      body: ListView.separated(
        itemCount: scenarios.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final s = scenarios[i];
          return ListTile(
            leading: Icon(s.icon),
            title: Text(s.title),
            subtitle: Text(s.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => s.builder()),
            ),
          );
        },
      ),
    );
  }
}

class _Scenario {
  const _Scenario({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function() builder;
}
