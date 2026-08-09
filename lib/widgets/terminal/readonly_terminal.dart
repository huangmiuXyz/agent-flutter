import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:xterm2/xterm.dart';

import 'package:agent/store/theme_store.dart';
import 'package:agent/theme/custom_theme.dart';

import 'terminal_palette.dart';

/// 只读终端视图 — 在工具调用卡片内实时展示 `shell_command` 等工具的流式输出。
///
/// - 增量写入：外部传入完整文本，内部跟踪已写入长度，只 `write` 新增部分，
///   多次重建（流式事件触发 setState）不会重复输出；
/// - 只读：不接收键盘输入（与 `simulated_terminal` 的交互终端互补），
///   仍支持文本选择/复制；
/// - xterm 渲染：ANSI 颜色、光标重绘（进度条）、终端宽度自动换行原生支持。
class ReadonlyTerminalView extends HookWidget {
  const ReadonlyTerminalView({
    super.key,
    required this.text,
    this.maxHeight = 280,
  });

  /// 要显示的完整输出文本（执行中的增量累积，或历史重载时的完整结果）
  final String text;

  /// 最大高度，超出后终端内部滚动
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final brightness = useExistingSignal(
      ThemeStore.instance.effectiveBrightness,
    );
    final theme = buildTerminalTheme(custom, brightness.value);
    // 终端字体：终端专用设置 > 界面字体设置（默认 JetBrainsMono），
    // 与交互终端（XtermTerminalWidget）保持一致
    final terminalFontFamily = useExistingSignal(
      ThemeStore.instance.terminalFontFamily,
    );
    final textStyle = useMemoized(
      () => TerminalStyle(
        fontSize: custom.typography.bodySize,
        fontFamily:
            terminalFontFamily.value ??
            custom.typography.fontFamily ??
            kDefaultFontFamily,
      ),
      [
        custom.typography.bodySize,
        custom.typography.fontFamily,
        terminalFontFamily.value,
      ],
    );

    final terminal = useMemoized(() => Terminal(maxLines: 5000));
    final writtenLen = useRef(0);

    // text 变化（含首帧挂载）时写入增量。Terminal 实例生命周期随 widget：
    // 收起/滚动出视口重建后从当前 text 重新写入，内容不丢失。
    useEffect(() {
      if (text.length > writtenLen.value) {
        terminal.write(text.substring(writtenLen.value));
        writtenLen.value = text.length;
      }
      return null;
    }, [text, terminal]);

    return Container(
      height: maxHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: custom.radii.sm,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.centerLeft,
      child: TerminalView(
        terminal,
        readOnly: true,
        theme: theme,
        textStyle: textStyle,
      ),
    );
  }
}
