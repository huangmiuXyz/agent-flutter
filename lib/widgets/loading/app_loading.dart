import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/custom_theme.dart';

/// 九圆点波浪加载指示器
///
/// 3×3 网格，每个圆点依次呈现透明度 + 缩放动画，形成斜向波浪效果。
class AppLoading extends HookWidget {
  /// 圆点大小，默认 2
  final double dotSize;

  /// 圆点间距，默认 1
  final double dotSpacing;

  /// 动画周期，默认 1500ms
  final Duration duration;

  const AppLoading({
    super.key,
    this.dotSize = 2,
    this.dotSpacing = 1,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final controller = useAnimationController(duration: duration)..repeat();

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int col = 0; col < 3; col++)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int row = 0; row < 3; row++)
                    Padding(
                      padding: EdgeInsets.all(dotSpacing),
                      child: _AppLoadingDot(
                        value: controller.value,
                        index: row * 3 + col,
                        size: dotSize,
                        color: custom.colors.textSecondary,
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _AppLoadingDot extends StatelessWidget {
  final double value;
  final int index;
  final double size;
  final Color color;

  const _AppLoadingDot({
    required this.value,
    required this.index,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // 每个点错开 0.1s，形成斜向波浪效果
    final t = (value + index * 0.1) % 1.0;
    final opacity = t < 0.5
        ? 0.2 + 0.8 * (t / 0.5)
        : 1.0 - 0.8 * ((t - 0.5) / 0.5);
    final scale = t < 0.5
        ? 0.6 + 0.4 * (t / 0.5)
        : 1.0 - 0.4 * ((t - 0.5) / 0.5);

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
