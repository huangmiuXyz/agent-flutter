import 'dart:async';

/// Stream a markdown string in chunks to simulate an LLM API response.
///
/// Default behaviour mimics OpenAI / Anthropic SDKs: a few characters every
/// few milliseconds. Tune [chunkSize] and [delay] to taste.
Stream<String> mockStreamFromText(
  String fullText, {
  int chunkSize = 3,
  Duration delay = const Duration(milliseconds: 30),
}) async* {
  for (var i = 0; i < fullText.length; i += chunkSize) {
    final end = (i + chunkSize) > fullText.length ? fullText.length : i + chunkSize;
    yield fullText.substring(i, end);
    if (end < fullText.length) {
      await Future<void>.delayed(delay);
    }
  }
}

/// Convenience: word-by-word streaming. Drops one word at a time, including
/// its trailing whitespace. Useful for a more "typing" feel.
Stream<String> mockWordStream(
  String fullText, {
  Duration delay = const Duration(milliseconds: 60),
}) async* {
  final pattern = RegExp(r'\S+\s*|\s+');
  for (final match in pattern.allMatches(fullText)) {
    yield match.group(0)!;
    await Future<void>.delayed(delay);
  }
}
