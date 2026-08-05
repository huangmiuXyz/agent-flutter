import 'package:flutter/material.dart';
import 'package:streamdown/streamdown.dart';

import '../mock_stream.dart';

/// Scenario 2 — what an actual chat UI looks like with streamdown.
///
/// The "AI response" is a hard-coded markdown blob streamed word-by-word.
/// To wire up a real provider, replace [_mockReply] with your SDK's
/// `Stream<String>` of response chunks.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final List<_Turn> _turns = <_Turn>[];
  final TextEditingController _input = TextEditingController(
    text: 'How do I sort a list in Dart?',
  );
  bool _busy = false;

  static const _mockReply = '''
You have a couple of options for sorting a `List` in Dart.

## In-place sort

```dart
final numbers = [3, 1, 4, 1, 5, 9, 2, 6];
numbers.sort();
print(numbers); // [1, 1, 2, 3, 4, 5, 6, 9]
```

The default `sort()` uses the elements' natural ordering. For custom
ordering, pass a comparator:

```dart
final names = ['Charlie', 'alice', 'Bob'];
names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
```

## Sorted copy (non-mutating)

If you need to keep the original list untouched:

```dart
final sorted = [...numbers]..sort();
```

That's the most idiomatic — spread into a new list, then sort.
''';

  Future<void> _send() async {
    final question = _input.text.trim();
    if (question.isEmpty || _busy) return;

    setState(() {
      _turns.add(_Turn.user(question));
      _input.clear();
      _busy = true;
    });

    // In a real app, replace this with your SDK's response stream.
    final stream = mockWordStream(_mockReply);
    setState(() => _turns.add(_Turn.assistant(stream)));

    await stream.drain<void>();
    if (!mounted) return;
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('2. AI chat simulator')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _turns.length,
              itemBuilder: (context, i) => _TurnBubble(turn: _turns[i]),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: const InputDecoration(
                        hintText: 'Ask a question…',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }
}

class _Turn {
  const _Turn.user(this.text)
      : isUser = true,
        stream = null;
  const _Turn.assistant(Stream<String> this.stream)
      : isUser = false,
        text = null;

  final bool isUser;
  final String? text;
  final Stream<String>? stream;
}

class _TurnBubble extends StatelessWidget {
  const _TurnBubble({required this.turn});

  final _Turn turn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: turn.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        decoration: BoxDecoration(
          color: turn.isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: turn.isUser
            ? Text(
                turn.text!,
                style: TextStyle(color: theme.colorScheme.onPrimary),
              )
            : Streamdown(stream: turn.stream!),
      ),
    );
  }
}
