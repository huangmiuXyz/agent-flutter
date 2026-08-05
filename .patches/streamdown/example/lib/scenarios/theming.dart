import 'package:flutter/material.dart';
import 'package:streamdown/streamdown.dart';

/// Scenario 3 — three SyntaxThemes side-by-side on the same code.
class ThemingScreen extends StatelessWidget {
  const ThemingScreen({super.key});

  static const _md = '''
```dart
class User {
  final String name;
  final int age;

  const User({required this.name, required this.age});

  bool get isAdult => age >= 18;
}
```
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3. Syntax theme gallery')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _ThemeCard(
            label: 'SyntaxTheme.githubLight()',
            theme: SyntaxTheme.githubLight(),
          ),
          const SizedBox(height: 16),
          _ThemeCard(
            label: 'SyntaxTheme.atomOneDark()',
            theme: SyntaxTheme.atomOneDark(),
          ),
          const SizedBox(height: 16),
          _ThemeCard(
            label: 'SyntaxTheme.auto(context)',
            theme: SyntaxTheme.auto(context),
          ),
        ],
      ),
    );
  }

  static Widget _build(SyntaxTheme theme) =>
      Streamdown.text(_md, syntaxTheme: theme);
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.label, required this.theme});

  final String label;
  final SyntaxTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFamily: 'monospace',
                ),
          ),
        ),
        ThemingScreen._build(theme),
      ],
    );
  }
}
