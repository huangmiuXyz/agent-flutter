import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'features/editor/editor_window.dart';
import 'rust_bridge/frb_generated.dart' as frb;
import 'services/engine/engine_client.dart';
import 'services/engine/frontend_tools.dart';
import 'services/font_cache/imported_font_service.dart';
import 'store/code_forge_store.dart';
import 'store/session_store.dart';
import 'store/xterm_store.dart';
import 'services/sync/app_sync.dart';
import 'services/sync/cross_window_sync.dart';
import 'services/llm/llm_service.dart';
import 'theme/app_theme.dart';
import 'utils/ime_composing_tracker.dart';

import 'package:code_forge/code_forge.dart' as code_forge;
import 'package:marionette_flutter/marionette_flutter.dart';

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
      // Debug 模式初始化 MarionetteBinding，向 AI agent 暴露 MCP 交互扩展；
      // 单 binding 规则：flutter test 环境下跳过，避免与测试 binding 冲突。
      final isFlutterTest = Platform.environment.containsKey('FLUTTER_TEST');
      if (kDebugMode && !isFlutterTest) {
        MarionetteBinding.ensureInitialized();
      } else {
        WidgetsFlutterBinding.ensureInitialized();
      }

      // 监听 textinput 通道消息，跟踪输入法组合状态
      // （Enter 发送类快捷键在组合中不应触发发送）
      ImeComposingTracker.instance.install();

      // 尽早注册本地导入字体（FontLoader 全局注册，幂等）
      unawaited(ImportedFontService.instance.loadAll());

      await frb.RustLib.init();
      await code_forge.RustLib.init();
      await LlmService().init();

      // Check if this is a child window (editor child windows).
      try {
        final controller = await WindowController.fromCurrentEngine();

        // ── 编辑器子窗口 ──
        if (controller.arguments.startsWith('editor:')) {
          // CodeForgeStore 已通过文件持久化拿到最新路径
          final store = CodeForgeStore.instance;

          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await windowManager.ensureInitialized();
            await windowManager.setTitle(
              '编辑 — ${store.filePath.value.split('/').last}',
            );
            await windowManager.center();
            await windowManager.focus();
            await windowManager.setPreventClose(true);
            windowManager.addListener(
              WindowCloseIntercept(() => windowManager.hide()),
            );
          });

          await initAppSync();
          // 监听其他窗口发来的文件切换通知
          CrossWindowSync.on('fileOpened', (_) {
            store.reload();
            unawaited(
              windowManager.setTitle(
                '编辑 — ${store.filePath.value.split('/').last}',
              ),
            );
          });
          // 检查点恢复：当前打开的文件受影响时重新加载
          CrossWindowSync.on('checkpointRestored', (args) {
            final affected = (args as List?)?.whereType<String>() ?? const [];
            if (affected.contains(store.filePath.value)) {
              store.reload();
            }
          });

          runApp(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              title: '编辑 — ${store.filePath.value.split('/').last}',
              theme: appLightTheme,
              darkTheme: appDarkTheme,
              home: EditorWindow(filePath: store.filePath.value),
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
        // 启动即最大化：先最大化再显示，避免窗口先以小尺寸出现
        await windowManager.maximize();
        await windowManager.show();
        await windowManager.focus();

        // 启动后自动聚焦 AI 聊天输入框：ChatInput 监听该计数器，
        // 首帧后请求焦点（窗口刚显示时组件可能尚未挂载，计数器值
        // 在挂载后的首次 effect 运行中同样生效）
        XtermStore.instance.chatFocusRequestCount.value++;
      });

      await initAppSync();
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
