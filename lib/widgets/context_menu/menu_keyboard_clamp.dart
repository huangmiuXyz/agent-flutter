import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Overlay 锚定下拉菜单的键盘避让。
///
/// 锚定式下拉（Overlay + CompositedTransformFollower）不会像 Scaffold 底部
/// 输入框那样随键盘收缩，键盘弹出时菜单可能被软键盘盖住。本组件在键盘弹出
/// （`viewInsets.bottom > 0`）时把整个菜单上移，使其底部不越过键盘上沿。
///
/// 只处理「向下展开」（[showAbove] == false）的情况 —— 向上展开的菜单已在
/// 锚点上方、远离键盘，无需避让。
///
/// [anchorBottom]：锚点按钮的全局底部纵坐标；[gap]：菜单与锚点间距；
/// [margin]：菜单距屏幕边缘最小留白。菜单高度在布局后实测 —— 只取**高度**，
/// 不受 CompositedTransformFollower 的 paint 偏移影响（该偏移无法被
/// `localToGlobal` 捕捉，但尺寸与位置无关，可安全测量）。
class MenuKeyboardClamp extends HookWidget {
  const MenuKeyboardClamp({
    super.key,
    required this.anchorBottom,
    required this.showAbove,
    required this.gap,
    required this.margin,
    required this.child,
  });

  /// 锚点按钮的全局底部纵坐标。
  final double anchorBottom;

  /// 菜单是否向上展开（向上展开时不避让）。
  final bool showAbove;

  /// 菜单与锚点的间距（展开方向的 offset）。
  final double gap;

  /// 菜单距屏幕底部/顶部的最小留白。
  final double margin;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;
    final menuKey = useRef<GlobalKey>(GlobalKey());
    final dy = useState<double>(0);

    useEffect(() {
      dy.value = 0;
      if (inset <= 0 || showAbove) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final box =
            menuKey.value.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.attached) return;
        final menuH = box.size.height;
        final availableBottom = screenH - inset - margin;
        // 向下展开：菜单顶部 = 锚点底 + 间距
        final menuTop = anchorBottom + gap;
        final over = menuTop + menuH - availableBottom;
        if (over > 0) {
          // 最多上移到菜单顶部贴住边缘留白，避免把顶部顶出屏幕
          final canShift = math.max(0.0, menuTop - margin);
          dy.value = -math.min(over, canShift);
        }
      });
      return null;
    }, [inset, screenH, showAbove, anchorBottom, gap, margin]);

    // 键盘未弹出 / 向上展开：原样渲染，不做任何变换
    if (inset <= 0) return child;

    return Transform.translate(
      offset: Offset(0, dy.value),
      child: KeyedSubtree(key: menuKey.value, child: child),
    );
  }
}