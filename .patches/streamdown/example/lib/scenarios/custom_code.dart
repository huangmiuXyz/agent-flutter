import 'package:flutter/material.dart';
import 'package:streamdown/streamdown.dart';

/// Scenario 4 — replace the default code block widget entirely.
///
/// Shows a custom builder that renders a "card" with the language as a
/// chip, the code in a monospaced block, and a streaming spinner while
/// the block is incomplete.
class CustomCodeScreen extends StatelessWidget {
  const CustomCodeScreen({super.key});

  static const _md = '''
# Custom code block

This page uses a `codeBlockBuilder` to fully replace the default rendering.

```bash
brew install flutter
flutter create my_app
cd my_app && flutter run
```

```dart
void main() {
  print('Hello from a custom code block!');
}
```
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('4. Custom code block builder')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Streamdown.text(
          _md,
          codeBlockBuilder: (context, language, code, isComplete) =>
              _CustomCodeBlock(
            language: language,
            code: code,
            isComplete: isComplete,
          ),
        ),
      ),
    );
  }
}

class _CustomCodeBlock extends StatelessWidget {
  const _CustomCodeBlock({
    required this.language,
    required this.code,
    required this.isComplete,
  });

  final String? language;
  final String code;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Chip(
                label: Text(language ?? 'text'),
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              if (!isComplete)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            code,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
