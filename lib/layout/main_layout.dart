import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/text/app_text.dart';

/// The hidden settings child-window controller, created on first use.
WindowController? settingsWindow;

/// Show or lazily create the settings child window.
Future<void> showSettingsWindow() async {
  try {
    var w = settingsWindow;
    if (w == null) {
      w = await WindowController.create(
        const WindowConfiguration(arguments: 'settings', hiddenAtLaunch: true),
      );
      settingsWindow = w;
    }
    await w.show();
  } catch (e) {
    debugPrint('Failed to show settings window: $e');
  }
}

/// A title-bar button styled consistently with [WindowCaptionButton].
class _CaptionIconButton extends StatefulWidget {
  final Brightness? brightness;
  final Widget icon;
  final VoidCallback? onPressed;

  const _CaptionIconButton({
    this.brightness,
    required this.icon,
    this.onPressed,
  });

  @override
  State<_CaptionIconButton> createState() => _CaptionIconButtonState();
}

class _CaptionIconButtonState extends State<_CaptionIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  Color _bgColor(Brightness? brightness, bool hovered, bool pressed) {
    if (brightness == Brightness.dark) {
      if (pressed) return Colors.white.withValues(alpha: 0.0419);
      if (hovered) return Colors.white.withValues(alpha: 0.0605);
      return Colors.transparent;
    }
    if (pressed) return Colors.black.withValues(alpha: 0.0241);
    if (hovered) return Colors.black.withValues(alpha: 0.0373);
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = widget.brightness ?? Brightness.light;
    final bg = _bgColor(brightness, _hovered, _pressed);
    final isDark = brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          decoration: BoxDecoration(color: bg),
          child: Center(
            child: IconTheme(
              data: IconThemeData(
                color: isDark
                    ? Colors.white
                    : Colors.black.withValues(alpha: 0.8956),
              ),
              child: widget.icon,
            ),
          ),
        ),
      ),
    );
  }
}

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final bgColor = custom.colors.panel;

    final footer = Container(
      height: custom.controls.footerHeight,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: custom.colors.selected)),
        color: bgColor,
      ),
    );

    if (Platform.isMacOS) {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kWindowCaptionHeight),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              border: Border(
                bottom: BorderSide(color: custom.colors.selected),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Draggable area (leave space for traffic lights).
                Expanded(
                  child: DragToMoveArea(
                    child: SizedBox(
                      height: kWindowCaptionHeight,
                    ),
                  ),
                ),
                // Small settings gear icon on the far right.
                Padding(
                  padding: EdgeInsets.only(right: custom.spacing.md),
                  child: AppIconButton(
                  icon: 'settings',
                  size: ButtonSize.sm,
                  hoverStyle: false,
                  onPressed: showSettingsWindow,
                ),
                ),
              ],
            ),
          ),
        ),
        body: child,
        bottomNavigationBar: footer,
      );
    }

    final brightness = custom.brightness;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kWindowCaptionHeight),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(bottom: BorderSide(color: custom.colors.selected)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DragToMoveArea(
                  child: SizedBox(
                    height: kWindowCaptionHeight,
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        const AppText('Agent'),
                      ],
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(16, 0),
                child: _CaptionIconButton(
                  brightness: brightness,
                  icon: const Icon(LucideIcons.settings, size: 12),
                  onPressed: showSettingsWindow,
                ),
              ),
              IntrinsicWidth(
                child: WindowCaption(
                  brightness: brightness,
                  title: const SizedBox.shrink(),
                  backgroundColor: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
      body: child,
      bottomNavigationBar: footer,
    );
  }
}
