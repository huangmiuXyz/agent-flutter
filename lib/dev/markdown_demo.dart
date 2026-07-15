import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';
import 'package:agent/widgets/card/app_card.dart';
import 'package:agent/widgets/markdown/markdown_preview.dart';
import 'package:streamdown/streamdown.dart' show SyntaxTheme;

/// A demo page showcasing [MarkdownPreview] with streaming animation.
///
/// Demonstrates:
/// 1. Static markdown rendering.
/// 2. Simulated AI streaming with word-by-word append and a blinking cursor.
/// 3. Send / restart streaming with a button.
class MarkdownDemo extends HookWidget {
  const MarkdownDemo({super.key});

  // ── A markdown sample rich enough to show headings, lists, tables, etc. ──
  static const String _staticSource = '''
# 欢迎使用 Streamdown

**Streamdown** 是一个 *高性能* 的流式 Markdown 渲染器。

## 特性

- ✨ **零闪烁** — 增量 AST 解析，不会在每个 chunk 重新解析全文
- 🚀 **高性能** — 比 `flutter_markdown` 快约 **188 倍**
- 📝 **暂态渲染** — 代码块、表格在半完成状态下即可预览
- 🔗 **链接支持** — 自动识别 URL 并支持点击打开
- 🎨 **代码高亮** — 内置多种语法高亮主题

### 代码块示例

```dart
void main() {
  print('Hello, Streamdown!');
  // 增量解析，无需重新 tokenize 前缀
  for (var i = 0; i < 100; i++) {
    print('Numbers: \$i');
  }
}
```

### 表格

| 功能 | Streamdown | flutter_markdown |
|------|-----------|-----------------|
| 增量解析 | ✅ | ❌ |
| 暂态渲染 | ✅ | ❌ |
| 稳定 Key | ✅ | ❌ |
| 行级缓存 | ✅ | ❌ |
''';

  /// The streaming demo content — words will be emitted one by one.
  static const String _streamingSource = '''
# 流式 Markdown 渲染

这是通过 **Streamdown** 逐字追加的演示文本。

## 实时效果

> 文字会像 AI 聊天一样 **逐字** 出现。
> 你可以观察到半成品的代码块和表格如何平滑渲染。

### 列表

- 第一项：增量解析
- 第二项：暂态渲染
- 第三项：稳定 widget key

### 行内代码

使用 `Streamdown(stream: myStream)` 即可开始流式渲染。

### 代码块（流式）

```python
# 这是一个正在流式输出的 Python 函数
def stream_markdown():
    chunks = ["Hello", " **World**", " from", " Streamdown!"]
    for chunk in chunks:
        yield chunk
```

### 表格（流式）

| 框架 | 速度 | 稳定性 |
|------|------|--------|
| Streamdown | 🚀 极快 | ✅ 稳定 |
| flutter_markdown | 🐢 较慢 | ❌ 闪烁 |

## 说明

使用 `MarkdownPreviewController` 配合 `MarkdownPreview` 实现：

```dart
final ctrl = MarkdownPreviewController();
ctrl.append(chunk);  // 每收到一块内容就追加
ctrl.done();         // 流结束后调用
MarkdownPreview(controller: ctrl)
```
''';

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final streamingTab = useState(0);
    final isStreaming = useState(false);
    final ctrlState = useState<MarkdownPreviewController?>(null);
    final streamedWords = useState(0);
    final totalWords = useState(0);

    // We keep the timer in a ref so we can cancel it from callbacks.
    final timerRef = useRef<Timer?>(null);

    // Increment on each stream restart to force-fresh Streamdown widget.
    final streamKey = useState(0);

    // Clean up on dispose
    useEffect(() {
      return () {
        timerRef.value?.cancel();
        ctrlState.value?.dispose();
      };
    }, []);

    // ── Tab switching ──
    final tabs = ['静态预览', '流式动画'];

    return Padding(
      padding: EdgeInsets.only(
        left: custom.spacing.lg,
        right: custom.spacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          AppText('Markdown 预览', variant: AppTextVariant.title),
          SizedBox(height: custom.spacing.sm),
          AppText(
            '使用 streamdown 实现零闪烁的流式 Markdown 渲染',
            variant: AppTextVariant.caption,
            color: custom.colors.textSecondary,
          ),
          SizedBox(height: custom.spacing.xl),

          // ── Tab bar ──
          Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Padding(
                  padding: EdgeInsets.only(right: custom.spacing.sm),
                  child: _TabChip(
                    label: tabs[i],
                    active: streamingTab.value == i,
                    onTap: () {
                      timerRef.value?.cancel();
                      ctrlState.value?.dispose();
                      ctrlState.value = null;
                      isStreaming.value = false;
                      streamingTab.value = i;
                    },
                  ),
                ),
            ],
          ),
          SizedBox(height: custom.spacing.lg),

          // ── Content ──
          if (streamingTab.value == 0)
            _buildStaticSection(context, custom)
          else
            _buildStreamingSection(
              context,
              custom,
              isStreaming,
              ctrlState,
              timerRef,
              streamKey,
              streamedWords,
              totalWords,
            ),
        ],
      ),
    );
  }

  // ── Static preview ──
  Widget _buildStaticSection(BuildContext context, CustomTheme custom) {
    return AppCard(
      minWidth: 400,
      padding: EdgeInsets.all(custom.spacing.md),
      child: MarkdownPreview(
        text: _staticSource,
        syntaxTheme: SyntaxTheme.auto(context),
        selectable: true,
        latex: false,
      ),
    );
  }

  // ── Streaming section ──
  Widget _buildStreamingSection(
    BuildContext context,
    CustomTheme custom,
    ValueNotifier<bool> isStreaming,
    ValueNotifier<MarkdownPreviewController?> ctrlState,
    ObjectRef<Timer?> timerRef,
    ValueNotifier<int> streamKey,
    ValueNotifier<int> streamedWords,
    ValueNotifier<int> totalWords,
  ) {
    final words = _streamingSource.split(' ').expand((w) => ["$w "]).toList();

    void startStream() {
      timerRef.value?.cancel();
      ctrlState.value?.dispose();

      streamKey.value++;
      final ctrl = MarkdownPreviewController();
      ctrlState.value = ctrl;
      streamedWords.value = 0;
      totalWords.value = words.length;
      isStreaming.value = true;

      var index = 0;
      timerRef.value = Timer.periodic(const Duration(milliseconds: 50), (
        timer,
      ) {
        if (index >= words.length) {
          timer.cancel();
          ctrl.done();
          isStreaming.value = false;
          return;
        }
        ctrl.append(words[index]);
        streamedWords.value = index + 1;
        index++;
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Controls ──
        Row(
          children: [
            _StreamButton(
              isStreaming: isStreaming.value,
              onPressed: isStreaming.value
                  ? () {
                      timerRef.value?.cancel();
                      ctrlState.value?.done();
                      isStreaming.value = false;
                    }
                  : startStream,
            ),
            SizedBox(width: custom.spacing.md),
            // Progress indicator
            if (isStreaming.value || streamedWords.value > 0)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(
                  horizontal: custom.spacing.sm,
                  vertical: custom.spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: custom.colors.panelElevated,
                  borderRadius: custom.radii.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isStreaming.value) ...[
                      _StreamingIndicator(),
                      SizedBox(width: custom.spacing.sm),
                    ],
                    AppText(
                      isStreaming.value
                          ? '追加中 ${streamedWords.value}/${totalWords.value}'
                          : '完成 (${totalWords.value} tokens)',
                      variant: AppTextVariant.caption,
                      color: isStreaming.value
                          ? custom.colors.accent
                          : custom.colors.textSecondary,
                    ),
                  ],
                ),
              ),
          ],
        ),
        SizedBox(height: custom.spacing.md),
        // ── Preview ──
        AppCard(
          minWidth: 400,
          padding: EdgeInsets.all(custom.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Only render MarkdownPreview when controller is ready.
              // Avoid creating empty closed controllers that cause layout errors.
              if (ctrlState.value != null)
                SizedBox(
                  width: double.infinity,
                  child: MarkdownPreview(
                    key: ValueKey(streamKey.value),
                    controller: ctrlState.value,
                    syntaxTheme: SyntaxTheme.auto(context),
                    selectable: true,
                    latex: false,
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: custom.spacing.xl * 2,
                  ),
                  child: Center(
                    child: AppText(
                      '点击「发送」开始流式演示',
                      color: custom.colors.textSecondary,
                    ),
                  ),
                ),
              // ── Blinking cursor at the end while streaming ──
              if (isStreaming.value)
                Padding(
                  padding: EdgeInsets.only(top: custom.spacing.xs),
                  child: _BlinkingCursor(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tab chip widget ──
class _TabChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: custom.spacing.md,
          vertical: custom.spacing.sm,
        ),
        decoration: BoxDecoration(
          color: active
              ? custom.colors.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: custom.radii.sm,
          border: Border.all(
            color: active ? custom.colors.accent : Colors.transparent,
          ),
        ),
        child: AppText(
          label,
          color: active ? custom.colors.accent : custom.colors.textSecondary,
        ),
      ),
    );
  }
}

// ── Stream start/stop button ──
class _StreamButton extends StatelessWidget {
  final bool isStreaming;
  final VoidCallback onPressed;

  const _StreamButton({required this.isStreaming, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: custom.spacing.md,
          vertical: custom.spacing.sm,
        ),
        decoration: BoxDecoration(
          color: isStreaming ? custom.colors.selected : custom.colors.accent,
          borderRadius: custom.radii.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              isStreaming ? 'stopCircle' : 'play',
              size: custom.typography.subtitleSize,
              color: isStreaming
                  ? custom.colors.textPrimary
                  : custom.colors.onAccent,
            ),
            SizedBox(width: custom.spacing.sm),
            AppText(
              isStreaming ? '停止' : '发送',
              color: isStreaming
                  ? custom.colors.textPrimary
                  : custom.colors.onAccent,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Blinking cursor widget ──
class _BlinkingCursor extends HookWidget {
  const _BlinkingCursor();

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 600),
    );

    useEffect(() {
      controller.repeat(reverse: true);
      return null;
    }, []);

    return FadeTransition(
      opacity: controller,
      child: ExcludeSemantics(
        child: Container(
          width: 2,
          height: custom.typography.bodySize,
          decoration: BoxDecoration(
            color: custom.colors.accent,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}

// ── Animated streaming dots ──
class _StreamingIndicator extends HookWidget {
  const _StreamingIndicator();

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    );

    useEffect(() {
      controller.repeat();
      return null;
    }, []);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final value = controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final dotValue = ((value * 3 - i) % 1.0).clamp(0.0, 1.0);
            final opacity = 0.3 + 0.7 * (1 - (dotValue - 0.5).abs() * 2);
            return Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: custom.colors.accent.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
