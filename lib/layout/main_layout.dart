import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:agent/widgets/text/app_text.dart';

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (Platform.isMacOS) {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kWindowCaptionHeight),
          child: DragToMoveArea(
            child: const SizedBox(height: kWindowCaptionHeight),
          ),
        ),
        body: child,
      );
    }

    final brightness = Theme.of(context).brightness;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kWindowCaptionHeight),
        child: WindowCaption(
          brightness: brightness,
          title: const AppText('Agent'),
        ),
      ),
      body: child,
    );
  }
}
