import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/text/app_text.dart';

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final bgColor = custom.surfaceContainerLow;

    if (Platform.isMacOS) {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kWindowCaptionHeight),
          child: DragToMoveArea(
            child: Container(
              height: kWindowCaptionHeight,
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  bottom: BorderSide(color: custom.surfaceContainerHighest),
                ),
              ),
            ),
          ),
        ),
        body: child,
      );
    }

    final brightness = Theme.of(context).brightness;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kWindowCaptionHeight),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: custom.surfaceContainerHighest),
            ),
          ),
          child: WindowCaption(
            brightness: brightness,
            title: const AppText('Agent'),
            backgroundColor: bgColor,
          ),
        ),
      ),
      body: child,
    );
  }
}
