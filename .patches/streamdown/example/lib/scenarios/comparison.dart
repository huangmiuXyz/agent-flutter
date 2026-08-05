import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:streamdown/streamdown.dart';

import '../mock_stream.dart';

/// Scenario 1 — the headline demo.
///
/// Two panes, same mocked LLM stream split into both. `flutter_markdown`
/// re-parses the whole string on every chunk → flicker. `streamdown` keeps
/// closed nodes stable → smooth.
class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  String _buffer = '';
  bool _streaming = false;

  static const _markdown = '''
# Compound interest demo

Compound interest is "interest on interest" — the snowball effect that
makes long-term investing powerful.

The formula:

```python
def future_value(principal, rate, years):
    """Returns the future value with annual compounding."""
    return principal * (1 + rate) ** years
```

| Principal | Rate | Years | Future value |
|----------:|-----:|------:|-------------:|
| 1000      | 5%   | 10    | 1628.89      |
| 1000      | 7%   | 20    | 3869.68      |
| 1000      | 10%  | 30    | 17449.40     |

> **Key insight:** the time variable is the most important one.
> A small rate over many years beats a large rate over few years.

Want to learn more? See <https://en.wikipedia.org/wiki/Compound_interest>.
''';

  Future<void> _start() async {
    setState(() {
      _streaming = true;
      _buffer = '';
    });
    await for (final chunk in mockStreamFromText(_markdown)) {
      if (!mounted) return;
      setState(() => _buffer += chunk);
    }
    if (!mounted) return;
    setState(() => _streaming = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('1. Comparison demo')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _streaming ? null : _start,
                  icon: Icon(_streaming ? Icons.refresh : Icons.play_arrow),
                  label: Text(_streaming ? 'Streaming…' : 'Stream again'),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_buffer.length} / ${_markdown.length} chars',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _Pane(
                    title: 'flutter_markdown',
                    color: Colors.red.shade100,
                    child: Markdown(data: _buffer),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _Pane(
                    title: 'streamdown',
                    color: Colors.green.shade100,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Streamdown.text(_buffer),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pane extends StatelessWidget {
  const _Pane({
    required this.title,
    required this.color,
    required this.child,
  });

  final String title;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: color,
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
