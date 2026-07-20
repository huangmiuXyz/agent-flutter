import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:agent/widgets/context_menu/context_menu.dart';
import 'package:agent/theme/custom_theme.dart';

/// Demo page for Fleather rich text editor with @mention support.
class FleatherDemo extends StatefulWidget {
  const FleatherDemo({super.key});

  @override
  State<FleatherDemo> createState() => _FleatherDemoState();
}

class _FleatherDemoState extends State<FleatherDemo> {
  late FleatherController _controller;
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<EditorState> _editorKey = GlobalKey();

  // --- @mention state ---
  int? _mentionStartIndex;
  String _mentionQuery = '';
  bool get _showMentionSuggestions => _mentionStartIndex != null;

  /// Mock users for @mention suggestions.
  final List<String> _users = const [
    'Alice Wang',
    'Bob Chen',
    'Charlie Li',
    'David Zhang',
    'Eva Liu',
    'Frank Yang',
    'Grace Wu',
    'Henry Huang',
    'Ivy Zhou',
    'Jack Xu',
  ];

  @override
  void initState() {
    super.initState();
    _controller = FleatherController();
    _controller.addListener(_onControllerChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _focusNode.removeListener(_onFocusChanged);
    ContextMenu.dismiss();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // @mention detection
  // ---------------------------------------------------------------------------

  void _onControllerChanged() {
    _checkForMention();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateMentionOverlay();
    });
  }

  void _checkForMention() {
    final selection = _controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      _clearMention();
      return;
    }

    final cursorPos = selection.baseOffset;
    final text = _controller.document.toPlainText();
    if (cursorPos > text.length) {
      _clearMention();
      return;
    }

    // Scan backward from cursor to find "@" preceded by whitespace or start.
    int? atPos;
    for (int i = cursorPos - 1; i >= 0; i--) {
      final char = text[i];
      if (char == '@') {
        // Ensure '@' is at word boundary (start of text or preceded by space/newline)
        if (i == 0 || text[i - 1] == ' ' || text[i - 1] == '\n') {
          atPos = i;
        }
        break;
      }
      // Stop at any non-word character (including punctuation & whitespace)
      if (!RegExp(r'[a-zA-Z0-9_\u4e00-\u9fff]').hasMatch(char)) {
        break;
      }
    }

    if (atPos != null) {
      final query = text.substring(atPos + 1, cursorPos);
      if (_mentionStartIndex != atPos || _mentionQuery != query) {
        setState(() {
          _mentionStartIndex = atPos;
          _mentionQuery = query;
        });
      }
    } else {
      _clearMention();
    }
  }

  void _clearMention() {
    if (_mentionStartIndex != null) {
      setState(() {
        _mentionStartIndex = null;
        _mentionQuery = '';
      });
    }
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _clearMention();
    }
  }

  void _updateMentionOverlay() {
    if (!_showMentionSuggestions || _filteredUsers.isEmpty) {
      ContextMenu.dismiss();
      return;
    }

    final editorState = _editorKey.currentState;
    if (editorState == null) {
      ContextMenu.dismiss();
      return;
    }

    // Get cursor (caret) position from the editor's renderer.
    final selection = _controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      ContextMenu.dismiss();
      return;
    }

    final renderBox = editorState.renderEditor as RenderBox;
    final endpoints = editorState.renderEditor.getEndpointsForSelection(
      selection,
    );
    if (endpoints.isEmpty) {
      ContextMenu.dismiss();
      return;
    }
    final cursorGlobalPos = renderBox.localToGlobal(endpoints[0].point);

    ContextMenu.show(
      context,
      position: Offset(cursorGlobalPos.dx, cursorGlobalPos.dy + 2),
      minWidth: 260,
      maxHeight: 280,
      autoFocus: false,
      items: [
        ..._filteredUsers.asMap().entries.map((entry) {
          return MenuItem(
            icon: 'atSign',
            label: entry.value,

            onTap: () => _selectMention(entry.value),
          );
        }),
      ],
    );
  }

  List<String> get _filteredUsers {
    if (_mentionQuery.isEmpty) return _users;
    return _users
        .where((u) => u.toLowerCase().contains(_mentionQuery.toLowerCase()))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Insert mention
  // ---------------------------------------------------------------------------

  void _selectMention(String user) {
    // Live state is always valid now (no focus steal from HardwareKeyboard mode).
    final startIndex = _mentionStartIndex;
    if (startIndex == null) return;
    final length = _mentionQuery.length + 1; // '@' + typed query

    _controller.replaceText(
      startIndex,
      length,
      EmbeddableObject('mention', inline: true, data: {'user': user}),
    );
    // Insert a trailing space so the user can keep typing.
    _controller.replaceText(
      startIndex + 1,
      0,
      ' ',
      selection: TextSelection.collapsed(offset: startIndex + 2),
    );
    _clearMention();
    _focusNode.requestFocus();
  }

  // ---------------------------------------------------------------------------
  // Embed builder – renders mentions and delegates other embeds to default
  // ---------------------------------------------------------------------------

  Widget _embedBuilder(BuildContext context, EmbedNode node) {
    if (node.value.type == 'mention') {
      final user = node.value.data['user'] as String? ?? '';
      final custom = CustomTheme.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: _MentionTag(
          color: custom.colors.hover,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '@$user',
              style: TextStyle(
                color: custom.colors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }
    return defaultFleatherEmbedBuilder(context, node);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Editor body
        Expanded(
          child: FleatherTheme(
            data: FleatherThemeData.fallback(context).copyWith(
              strutStyle: const StrutStyle(
                forceStrutHeight: true,
                fontSize: 14,
              ),
            ),
            child: FleatherEditor(
              controller: _controller,
              focusNode: _focusNode,
              editorKey: _editorKey,
              embedBuilder: _embedBuilder,
              clipboardManager: _MentionClipboardManager(_users),
              spellCheckConfiguration: SpellCheckConfiguration(
                spellCheckService: DefaultSpellCheckService(),
                misspelledSelectionColor: Colors.red,
                misspelledTextStyle:
                    theme.textTheme.bodyMedium ?? const TextStyle(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Clipboard manager that preserves @mention tags during copy/paste
// ---------------------------------------------------------------------------

/// Custom [ClipboardManager] for Fleather that handles [@mention](mention) embeds.
///
/// **Copy**: Converts mention embeds in Delta back to `@用户名` plain text so the
/// system clipboard gets readable text like "Hello @Alice Wang".
///
/// **Paste**: Scans pasted plain text for `@用户名` patterns that match known users
/// and reconstructs mention embeds in the Delta.
class _MentionClipboardManager extends ClipboardManager {
  final List<String> _knownUsers;

  const _MentionClipboardManager(this._knownUsers);

  /// Copy: translate mention embeds to `@用户名` in plain text.
  @override
  Future<void> setData(FleatherClipboardData data) async {
    String? text;

    if (data.delta != null) {
      text = _deltaToMentionText(data.delta!);
    } else {
      text = data.plainText;
    }

    if (text != null && text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  String _deltaToMentionText(Delta delta) {
    final buf = StringBuffer();
    for (final op in delta.toList()) {
      if (op.data is String) {
        buf.write(op.data);
      } else if (op.data is Map<String, dynamic>) {
        final map = op.data as Map<String, dynamic>;
        if (map['_type'] == 'mention') {
          buf.write('@${map['user'] ?? ''}');
        } else {
          buf.write('\uFFFC'); // object replacement char for other embeds
        }
      }
    }
    return buf.toString();
  }

  /// Paste: parse `@用户名` back into mention embeds.
  @override
  Future<FleatherClipboardData?> getData() async {
    final raw = await Clipboard.getData(Clipboard.kTextPlain);
    final text = raw?.text;
    if (text == null || text.isEmpty) return null;

    final delta = _mentionTextToDelta(text);
    return FleatherClipboardData(plainText: text, delta: delta);
  }

  Delta _mentionTextToDelta(String text) {
    final delta = Delta();

    // Sort longest-first so "Alice Wang" matches before "Alice"
    final sorted = List<String>.from(_knownUsers)
      ..sort((a, b) => b.length.compareTo(a.length));

    // Build regex: @(user1|user2|...) — case-insensitive
    final escaped = sorted.map((u) => RegExp.escape(u)).join('|');
    final pattern = RegExp('@($escaped)', caseSensitive: false);

    int last = 0;
    for (final m in pattern.allMatches(text)) {
      // Text before the mention
      if (m.start > last) {
        delta.insert(text.substring(last, m.start));
      }
      // Use canonical casing from the known users list
      final matchedName = m.group(1)!;
      final canonicalName = sorted.firstWhere(
        (u) => u.toLowerCase() == matchedName.toLowerCase(),
      );
      delta.insert(
        EmbeddableObject(
          'mention',
          inline: true,
          data: {'user': canonicalName},
        ).toJson(),
      );
      last = m.end;
    }
    // Remaining text after last mention
    if (last < text.length) {
      delta.insert(text.substring(last));
    }
    return delta;
  }
}

// ---------------------------------------------------------------------------
// Custom RenderBox for mention tag – no vertical padding in layout,
// so WidgetSpan's PlaceholderAlignment.bottom aligns text baseline correctly.
// Background extends into visual-only bottom padding.
// ---------------------------------------------------------------------------

class _MentionTag extends SingleChildRenderObjectWidget {
  final Color color;

  const _MentionTag({super.child, required this.color});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _MentionTagRenderBox(color: color);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _MentionTagRenderBox renderObject,
  ) {
    renderObject.color = color;
  }
}

class _MentionTagRenderBox extends RenderShiftedBox {
  _MentionTagRenderBox({required this._color}) : super(null);

  Color _color;

  Color get color => _color;
  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  static const double _topPadding = 1.0;
  static const double _bottomPadding = 0.0;
  static const double _borderRadius = 3.0;

  /// Layout height = childHeight + topPadding + bottomPadding.
  /// Visual background matches layout bounds, so no reflow on text change.
  @override
  void performLayout() {
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child!.layout(constraints, parentUsesSize: true);
    size = Size(
      child!.size.width,
      child!.size.height + _topPadding + _bottomPadding,
    );
  }

  /// Paint background + child (child shifted down by topPadding).
  /// Background fills the entire layout rect.
  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final bgRect = Offset(offset.dx, offset.dy) & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(_borderRadius)),
      Paint()..color = _color,
    );
    if (child != null) {
      context.paintChild(child!, offset + const Offset(0, _topPadding));
    }
  }

  /// Baseline = child baseline + topPadding (for parent layout inquiries).
  @override
  double computeDistanceToActualBaseline(TextBaseline baselineType) {
    final childBaseline =
        child?.computeDistanceToActualBaseline(baselineType) ?? 0;
    return childBaseline + _topPadding;
  }
}
