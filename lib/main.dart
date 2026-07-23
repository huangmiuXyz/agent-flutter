import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'features/settings/settings_page.dart';
import 'layout/main_layout.dart';
import 'theme/app_theme.dart';

void main() async {
  // Silence Fleather's harmless assertion in childAtPosition when
  // ballistic scroll races with document mutation.
  final oldErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception is AssertionError &&
        details.stack.toString().contains(
          'RenderEditableContainerBox.childAtPosition',
        )) {
      return;
    }
    oldErrorHandler?.call(details);
  };

  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Check if this is a child window (e.g. settings child window).
      try {
        final controller = await WindowController.fromCurrentEngine();
        if (controller.arguments == 'settings') {
          // Center the window after the first frame renders.
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await windowManager.ensureInitialized();
            await windowManager.center();
            await windowManager.focus();
          });
          runApp(const ProviderScope(child: _SettingsWindow()));
          return;
        }
      } catch (_) {
        // Not a child window — proceed to main window setup.
      }

      await windowManager.ensureInitialized();

      // Create the hidden settings child window and register it so the
      // gear button can bring it to front later.
      try {
        final ctrl = await WindowController.create(
          const WindowConfiguration(
            arguments: 'settings',
            hiddenAtLaunch: true,
          ),
        );
        settingsWindow = ctrl;
      } catch (e) {
        debugPrint('Failed to create settings window: $e');
      }

      const windowOptions = WindowOptions(
        size: Size(1200, 900),
        minimumSize: Size(400, 300),
        center: true,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
      );

      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });

      runApp(const ProviderScope(child: AgentApp()));
    },
    (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'agent',
          context: ErrorDescription('top-level unhandled error'),
        ),
      );
    },
  );
}

/// A minimal app shell for the settings child window.
class _SettingsWindow extends StatelessWidget {
  const _SettingsWindow();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Agent Settings',
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      home: const SettingsPage(),
    );
  }
}
