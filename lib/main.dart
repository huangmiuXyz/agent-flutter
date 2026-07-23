import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'features/settings/settings_page.dart';
import 'layout/main_layout.dart';
import 'rust_bridge/frb_generated.dart' as frb;
import 'services/config_service.dart';
import 'theme/app_theme.dart';
import 'utils/platform_dirs.dart';

/// Resolve config file path using the same logic as [ConfigPath] provider.
String _resolveConfigPath() {
  const compileEnv = String.fromEnvironment('CONFIG_PATH');
  if (compileEnv.isNotEmpty) return compileEnv;

  final runtimeEnv = Platform.environment['AGENT_CONFIG_PATH'];
  if (runtimeEnv != null && runtimeEnv.isNotEmpty) return runtimeEnv;

  if (File('./config.json').existsSync() ||
      File('./pubspec.yaml').existsSync() ||
      Directory('./data').existsSync()) {
    return '../agent-flutter-cli/config.json';
  }

  return appDataDir(['agent', 'config.json']);
}

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

      await frb.RustLib.init();

      // Resolve config path using the same logic as ConfigPath provider.
      final configPath = _resolveConfigPath();

      // Check if this is a child window (e.g. settings child window).
      try {
        final controller = await WindowController.fromCurrentEngine();
        if (controller.arguments == 'settings') {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await windowManager.ensureInitialized();
            await windowManager.center();
            await windowManager.focus();
            // Prevent close — hide instead of destroy so the gear
            // button can bring the window back to front later.
            await windowManager.setPreventClose(true);
            windowManager.addListener(
              WindowCloseIntercept(() => windowManager.hide()),
            );
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

/// Intercepts the native close event and runs [onClose] instead.
class WindowCloseIntercept with WindowListener {
  final VoidCallback onClose;

  WindowCloseIntercept(this.onClose);

  @override
  void onWindowClose() => onClose();
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
