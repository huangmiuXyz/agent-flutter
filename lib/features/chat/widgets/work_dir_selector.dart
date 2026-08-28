/// 聊天页工作目录选择器。
///
/// 显示在消息输入框工具栏内、智能体选择器左侧。
/// 点击弹出面板展示历史选择记录（单击选择 / 悬停行尾 x 删除），
/// 面板底部提供「从文件系统选择」入口。
///
/// 弹出的面板通过 rootOverlay + CompositedTransformFollower 悬浮在按钮旁，
/// 位置固定，不随页面内容滚动而变化。
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/agents/store/agent_store.dart';
import 'package:agent/services/mobile_work_dir.dart';
import 'package:agent/store/config_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/utils/platform.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/app_text_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/card/app_card.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/list/app_list.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 从完整路径提取最后一段作为文件夹名；空结果时回退完整路径。
String _dirName(String path) {
  var trimmed = path;
  while (trimmed.endsWith('/')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  final idx = trimmed.lastIndexOf('/');
  final name = idx < 0 ? trimmed : trimmed.substring(idx + 1);
  return name.isEmpty ? path : name;
}

/// 工作目录选择器（管理 [ConfigStore.workDir] 与历史记录）。
class WorkDirSelector extends HookWidget {
  const WorkDirSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final store = ConfigStore.instance;
    // 当前生效的工作目录（智能体 work_dir 优先，与发送消息时一致）；
    // 监听智能体切换与全局 work_dir 变化，确保按钮实时刷新
    useExistingSignal(AgentStore.instance.currentAgent);
    useExistingSignal(store.workDir);
    final workDir = AgentStore.instance.resolveWorkDir();

    final isHovered = useState(false);
    final isOpen = useState(false);
    final buttonKey = useMemoized(() => GlobalKey());
    final layerLink = useMemoized(() => LayerLink());
    final overlayRef = useRef<OverlayEntry?>(null);

    void dismiss() {
      overlayRef.value?.remove();
      overlayRef.value = null;
      isOpen.value = false;
    }

    void open() {
      final renderBox =
          buttonKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;

      final position = renderBox.localToGlobal(Offset.zero);
      final viewport = View.of(context);
      final screenWidth =
          viewport.physicalSize.width / viewport.devicePixelRatio;
      final buttonRight = position.dx + renderBox.size.width;
      final alignRight = buttonRight > screenWidth / 2;
      final anchorRect = position & renderBox.size;

      overlayRef.value = OverlayEntry(
        builder: (_) => _WorkDirMenu(
          position: position,
          link: layerLink,
          alignRight: alignRight,
          anchorRect: anchorRect,
          onDismiss: dismiss,
        ),
      );
      Overlay.of(context, rootOverlay: true).insert(overlayRef.value!);
      isOpen.value = true;
    }

    void onTap() {
      if (isOpen.value) {
        dismiss();
      } else {
        open();
      }
    }

    // 按钮内容：folder 图标 + 当前目录名（文本限宽 + 省略号截断）+ 展开箭头
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(
          'folder',
          size: custom.typography.captionSize,
          color: custom.colors.textSecondary,
        ),
        SizedBox(width: custom.spacing.xs),
        // 显式限宽而非 Flexible：避免在 Row(min) + Center 中把按钮撑满 220px
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: AppText(
            workDir.isEmpty ? '选择工作目录' : _dirName(workDir),
            variant: AppTextVariant.caption,
            color: workDir.isEmpty
                ? custom.colors.textSecondary
                : custom.colors.textPrimary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: custom.spacing.xs),
        AppIcon(
          isOpen.value ? 'chevronUp' : 'chevronDown',
          size: custom.typography.captionSize,
          color: custom.colors.textSecondary,
        ),
      ],
    );

    return CompositedTransformTarget(
      link: layerLink,
      child: MouseRegion(
        onEnter: (_) => isHovered.value = true,
        onExit: (_) => isHovered.value = false,
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            key: buttonKey,
            height: custom.controls.smallHeight,
            padding: EdgeInsets.symmetric(horizontal: custom.spacing.sm),
            decoration: BoxDecoration(
              color: (isHovered.value || isOpen.value)
                  ? custom.colors.hover
                  : Colors.transparent,
              borderRadius: custom.radii.xs,
            ),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}

// ──────────────────── 弹出面板 ────────────────────

class _WorkDirMenu extends HookWidget {
  /// 触发按钮的全局位置（用于决定面板向上/向下展开）。
  final Offset position;

  /// 锚点 [LayerLink]，面板通过 [CompositedTransformFollower] 跟随按钮。
  final LayerLink link;

  /// 是否靠右对齐（按钮靠近屏幕右侧时启用）。
  final bool alignRight;

  /// 锚定按钮矩形；点击该区域不关闭面板（交由按钮 onTap 决定收起）。
  final Rect anchorRect;

  /// 关闭面板。
  final VoidCallback onDismiss;

  const _WorkDirMenu({
    required this.position,
    required this.link,
    required this.alignRight,
    required this.anchorRect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final store = ConfigStore.instance;
    // 面板内同样展示「真正生效」的工作目录（智能体 work_dir 优先）
    useExistingSignal(AgentStore.instance.currentAgent);
    useExistingSignal(store.workDir);
    final workDir = AgentStore.instance.resolveWorkDir();
    final history = useExistingSignal(store.workDirHistory).value;

    // 面板首次布局后再显示，避免出现位置跳变
    final ready = useState(false);
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ready.value = true;
      });
      return null;
    }, const []);

    // 决定展开方向：按钮靠近屏幕下方则向上展开
    final viewport = View.of(context);
    final screenHeight =
        viewport.physicalSize.height / viewport.devicePixelRatio;
    final showAbove = position.dy >= screenHeight - position.dy;

    // 面板最大高度：最多显示 8 条历史 + 底部按钮区，超出由 AppCard 滚动。
    // 历史项为内容自适应高度（caption 行高 + 上下 padding），
    // 用 TextPainter 实测行高，保证字号缩放后的估算仍准确
    final captionStyle = custom.typography.styleForSize(
      custom.typography.captionSize,
      custom.colors.textPrimary,
    );
    final captionLine = TextPainter(
      text: TextSpan(text: 'Ag', style: captionStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final itemHeight = captionLine.height + 2 * custom.spacing.xs;
    final unitHeight = itemHeight + custom.spacing.xs;
    final maxPanelHeight = 8 * unitHeight + custom.controls.smallHeight + 48;

    Future<void> pickFromFileSystem() async {
      // 提前取 messenger：onDismiss 后本组件 context 失效
      final messenger = ScaffoldMessenger.maybeOf(context);
      // 先关闭面板，再弹出系统目录选择器
      onDismiss();

      // 移动端：SAF 选中目录无法直接读（std::fs 限制），
      // 导入副本到应用工作目录后再切换
      if (isMobilePlatform) {
        final imported = await MobileWorkDirService.instance.pickAndImport();
        if (imported == null) {
          messenger?.showSnackBar(
            const SnackBar(
              content: AppText('无法读取所选目录（Android 存储限制），已保留当前工作目录'),
            ),
          );
          return;
        }
        await AgentStore.instance.setWorkDir(imported);
        return;
      }

      try {
        final path = await FilePicker.getDirectoryPath();
        if (path != null && path.isNotEmpty) {
          // 写入「当前生效位置」（全局或当前智能体配置）
          await AgentStore.instance.setWorkDir(path);
        }
      } catch (_) {
        // 用户取消或选择失败，静默忽略
      }
    }

    final menuContent = Opacity(
      opacity: ready.value ? 1.0 : 0.0,
      child: Material(
        type: MaterialType.transparency,
        child: AppCard(
          minWidth: 240,
          maxWidth: custom.controls.contextMenuMaxWidth,
          maxHeight: maxPanelHeight,
          backgroundColor: custom.colors.menuBackground,
          border: Border.all(color: custom.colors.menuBorder, width: 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 面板标题
              Padding(
                padding: EdgeInsets.fromLTRB(
                  custom.spacing.sm,
                  custom.spacing.sm,
                  custom.spacing.sm,
                  custom.spacing.xs,
                ),
                child: AppText(
                  '最近的工作目录',
                  variant: AppTextVariant.caption,
                  color: custom.colors.textSecondary,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              // 历史记录列表
              if (history.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: custom.spacing.sm,
                    vertical: custom.spacing.sm,
                  ),
                  child: AppText(
                    '暂无历史记录',
                    variant: AppTextVariant.caption,
                    color: custom.colors.textDisabled,
                  ),
                )
              else
                AppList(
                  size: AppListSize.small,
                  children: [
                    for (final path in history)
                      AppListItem(
                        icon: 'folder',
                        // 只显示文件夹名，不显示完整路径
                        label: _dirName(path),
                        labelMaxLines: 1,
                        active: path == workDir,
                        // 与菜单 selected 一致：强调色低透明度叠加
                        activeColor: custom.colors.accent.withValues(
                          alpha: 0.12,
                        ),
                        itemRadius: custom.radii.sm,
                        // 内容自适应高度：字号缩放后文本行盒可能超过 smallHeight，
                        // 固定高度会把字母下伸部（g/j/p）顶到行尾遮住
                        intrinsicHeight: true,
                        // hover 时行尾浮出 x 删除按钮（不关闭面板）
                        hoverActions: [
                          AppIconButton(
                            icon: 'x',
                            size: ButtonSize.sm,
                            hoverStyle: false,
                            iconColor: custom.colors.danger,
                            onPressed: () => store.removeWorkDirHistory(path),
                          ),
                        ],
                        onTap: () {
                          // 写入「当前生效位置」（全局或当前智能体配置）
                          AgentStore.instance.setWorkDir(path);
                          onDismiss();
                        },
                      ),
                  ],
                ),
              // 底部按钮：从文件系统选择（紧凑，与历史行等高）
              Padding(
                padding: EdgeInsets.only(
                  left: custom.spacing.xs,
                  right: custom.spacing.xs,
                  top: custom.spacing.xs,
                ),
                child: AppTextButton(
                  icon: 'folderOpen',
                  text: '从文件系统选择',
                  size: ButtonSize.sm,
                  fullWidth: true,
                  onPressed: pickFromFileSystem,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Stack(
      children: [
        // 全屏 dismiss 背景；点击锚定按钮区域时不关闭，
        // 由按钮自身 onTap 决定收起或切换
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) {
              if (anchorRect.inflate(4).contains(event.position)) return;
              onDismiss();
            },
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: link,
          targetAnchor: showAbove
              ? (alignRight ? Alignment.topRight : Alignment.topLeft)
              : (alignRight ? Alignment.bottomRight : Alignment.bottomLeft),
          followerAnchor: showAbove
              ? (alignRight ? Alignment.bottomRight : Alignment.bottomLeft)
              : (alignRight ? Alignment.topRight : Alignment.topLeft),
          offset: Offset(
            0,
            showAbove ? -custom.spacing.edgeMargin : custom.spacing.edgeMargin,
          ),
          child: menuContent,
        ),
      ],
    );
  }
}
