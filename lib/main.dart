import 'dart:async';

import 'package:flutter/material.dart';

import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'features/editor/editor_window.dart';
import 'features/settings/settings_page.dart';
import 'rust_bridge/frb_generated.dart' as frb;
import 'services/sync/app_sync.dart';
import 'services/llm/llm_service.dart';
import 'theme/app_theme.dart';

import 'package:code_forge/code_forge.dart' as code_forge;

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
      await code_forge.RustLib.init();
      await LlmService().init();

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
          initAppSync();
          runApp(const _SettingsWindow());
          return;
        }

        // ── 编辑器子窗口 ──
        if (controller.arguments.startsWith('editor:')) {
          final filePath = controller.arguments.substring(7);
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await windowManager.ensureInitialized();
            await windowManager.setTitle('编辑 — ${filePath.split('/').last}');
            await windowManager.center();
            await windowManager.focus();
            await windowManager.setPreventClose(true);
            windowManager.addListener(
              WindowCloseIntercept(() => windowManager.hide()),
            );
          });
          initAppSync();
          runApp(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              title: '编辑 — ${filePath.split('/').last}',
              theme: appLightTheme,
              darkTheme: appDarkTheme,
              home: EditorWindow(filePath: filePath),
            ),
          );
          return;
        }
      } catch (_) {
        // Not a child window — proceed to main window setup.
      }

      await windowManager.ensureInitialized();

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

      initAppSync();
      runApp(const AgentApp());
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
