import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import 'package:agent/features/agents/models/agent_info.dart';
import 'package:agent/features/settings/models/provider_info.dart';
import 'package:agent/features/settings/settings_page.dart';
import 'package:agent/store/config_store.dart';
import 'package:agent/features/skills/store/skill_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/dialog/app_dialog.dart';
import 'package:agent/widgets/notification/stream_completion_notifications.dart';
import 'package:agent/widgets/text/app_text.dart';
import 'package:agent/rust_bridge/api/mcp.dart' as api;
import 'package:agent/rust_bridge/api/skills.dart' as api;

/// 设置面板单例标记：同一窗口内只允许一个设置弹窗，避免叠加多个。
bool _settingsPanelOpen = false;

/// 以模态弹窗形式显示设置页（主窗口内，与主窗口同 isolate）。
///
/// 尺寸跟随主窗口：宽 80%、高 90%。
/// 可通过 [tab]/[provider]/[agent] 直达对应设置子页面（如从聊天页选择器跳转）。
///
/// 面板是单例：已打开时不会叠加新面板，而是把已打开的面板导航到
/// 新请求的目标页（[tab]/[provider]/[agent]）。
Future<void> showSettingsDialog(
  BuildContext context, {
  SettingsTab? tab,
  ProviderInfo? provider,
  AgentInfo? agent,
}) async {
  final target = SettingsTarget(tab: tab, provider: provider, agent: agent);
  if (_settingsPanelOpen) {
    // 已有面板：就地导航，不叠加新弹窗
    settingsPanelTarget.value = target;
    return;
  }
  _settingsPanelOpen = true;
  settingsPanelTarget.value = target;
  try {
    final size = MediaQuery.sizeOf(context);
    final width = size.width * 0.8;
    final height = size.height * 0.9;
    await AppDialog.show(
      context: context,
      title: '设置',
      showFooter: false,
      width: width,
      // 设置页自身带内边距，弹窗 body 不再额外留白
      bodyPadding: EdgeInsets.zero,
      compactHeader: true,
      child: SizedBox(
        height: height,
        child: SettingsPage(
          initialTab: tab,
          initialProvider: provider,
          initialAgent: agent,
        ),
      ),
    );
  } finally {
    settingsPanelTarget.value = null;
    _settingsPanelOpen = false;
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
              border: Border(bottom: BorderSide(color: custom.colors.selected)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Draggable area (leave space for traffic lights).
                Expanded(
                  child: DragToMoveArea(
                    child: SizedBox(height: kWindowCaptionHeight),
                  ),
                ),
                // Small settings gear icon on the far right.
                Padding(
                  padding: EdgeInsets.only(right: custom.spacing.md),
                  child: AppIconButton(
                    icon: 'settings',
                    size: ButtonSize.sm,
                    hoverStyle: false,
                    onPressed: () => showSettingsDialog(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            child,
            const _McpInitSnackBar(),
            const StreamCompletionNotifications(),
          ],
        ),
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
                  onPressed: () => showSettingsDialog(context),
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
      body: Stack(
        children: [
          child,
          const _McpInitSnackBar(),
          const StreamCompletionNotifications(),
        ],
      ),
      bottomNavigationBar: footer,
    );
  }
}

/// 启动时初始化 MCP + 扫描技能
class _McpInitSnackBar extends StatefulWidget {
  const _McpInitSnackBar();

  @override
  State<_McpInitSnackBar> createState() => _McpInitSnackBarState();
}

class _McpInitSnackBarState extends State<_McpInitSnackBar> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 1. 初始化 MCP 连接
    try {
      final configPath = ConfigStore.instance.configPath;
      final errors = await api.initMcp(configPath: configPath);
      if (errors.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: AppText(errors.join('\n')),
              duration: const Duration(seconds: 5),
            ),
          );
        });
      }
    } catch (_) {}

    // 2. 扫描全局技能，确保第一次发消息时 buildSkillCatalog() 能返回结果
    //    即使未访问过设置→技能页面
    try {
      final discovered = await api.scanGlobalSkills();
      SkillStore.instance.load(discovered);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
