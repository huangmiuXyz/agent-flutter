import 'dart:async';

import 'package:flutter/material.dart';

import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'features/editor/editor_window.dart';
import 'features/settings/settings_page.dart';
import 'rust_bridge/frb_generated.dart' as frb;
import 'services/engine/engine_client.dart';
import 'services/engine/frontend_tools.dart';
import 'store/session_store.dart';
import 'store/xterm_store.dart';
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

      // ── 主窗口：连接统一引擎事件流 + 注册前端工具 ──
      // 注意：必须在子窗口检查之后调用，避免子窗口的 sink 覆盖主窗口的 sink
      // （ENGINE_SINK 是进程级单例，重复 connect 会覆盖）
      await EngineClient.instance.connect();
      await registerFrontendTools();

      await windowManager.ensureInitialized();

      // ── 主窗口关闭拦截：清理资源再退出 ──
      await windowManager.setPreventClose(true);
      windowManager.addListener(
        WindowCloseIntercept(() => unawaited(_cleanupAndCloseMainWindow())),
      );

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

/// 主窗口关闭时的资源清理。
///
/// 在用户关闭主窗口时依次执行：
/// 1. 取消所有活跃的 LLM 流（abort Rust 后台 task）
/// 2. 杀死所有 PTY 子进程（避免孤儿进程）
/// 3. 断开引擎事件流
/// 4. 短暂等待后台线程 flush
Future<void> _cleanupAndCloseMainWindow() async {
  try {
    // 1. 取消所有活跃流
    for (final sessionId in SessionStore.instance.streamingSessionIds.value) {
      await SessionStore.instance.cancelStreaming(sessionId);
    }

    // 2. 杀死所有 PTY 子进程
    XtermStore.instance.disposeAll();

    // 3. 断开引擎事件流
    await EngineClient.instance.disconnect();

    // 4. 给后台线程一点时间 flush（日志、DB 等）
    await Future.delayed(const Duration(milliseconds: 300));
  } catch (_) {
    // 清理失败不影响窗口关闭
  }

  await windowManager.destroy();
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
