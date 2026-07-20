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
          child: DragToMoveArea(
            child: Container(
              height: kWindowCaptionHeight,
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  bottom: BorderSide(color: custom.colors.selected),
                ),
              ),
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
            border: Border(bottom: BorderSide(color: custom.colors.selected)),
          ),
          child: WindowCaption(
            brightness: brightness,
            title: const AppText('Agent'),
            backgroundColor: bgColor,
          ),
        ),
      ),
      body: child,
      bottomNavigationBar: footer,
    );
  }
}
