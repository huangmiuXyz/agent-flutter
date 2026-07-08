import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agent/theme/provider.dart';
import 'package:agent/widgets/button/app_button.dart';

const ColorScheme _purpleColorScheme = ColorScheme.light(
  primary: Color(0xFF6750A4),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFEADDFF),
  onPrimaryContainer: Color(0xFF21005D),
  secondary: Color(0xFF625B71),
  onSecondary: Color(0xFFFFFFFF),
  surface: Color(0xFFFFFBFE),
  onSurface: Color(0xFF1C1B1F),
  error: Color(0xFFBA1A1A),
  onError: Color(0xFFFFFFFF),
);

class DemoPage extends ConsumerWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider.select(
      (c) => c.resolveBrightness() == Brightness.dark,
    ));
    final hasCustomColor = ref.watch(themeProvider.select(
      (c) => c.colorScheme != null,
    ));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppButton(
                  variant: ButtonVariant.iconOnly,
                  icon: isDark ? 'sun' : 'moon',
                  onPressed: () =>
                      ref.read(themeProvider.notifier).toggle(),
                ),
                const SizedBox(width: 8),
                AppButton(
                  variant: hasCustomColor
                      ? ButtonVariant.primary
                      : ButtonVariant.secondary,
                  icon: 'brush',
                  text: '换色',
                  onPressed: () {
                    final notifier = ref.read(themeProvider.notifier);
                    if (hasCustomColor) {
                      notifier.resetColorScheme();
                    } else {
                      notifier.setColorScheme(_purpleColorScheme);
                    }
                  },
                ),
              ],
            ),
          ),
          const Spacer(),
          AppButton(
            variant: ButtonVariant.primary,
            onPressed: () {},
            text: '发送',
          ),
          const SizedBox(height: 8),
          AppButton(
            variant: ButtonVariant.primary,
            onPressed: () {},
            text: '发送',
            size: ButtonSize.sm,
          ),
          const SizedBox(height: 8),
          AppButton(
            variant: ButtonVariant.primary,
            onPressed: () {},
            text: '发送',
            size: ButtonSize.lg,
          ),
          const SizedBox(height: 8),
          AppButton(
            variant: ButtonVariant.secondary,
            onPressed: () {},
            text: '取消',
          ),
          const SizedBox(height: 8),
          AppButton(
            variant: ButtonVariant.text,
            onPressed: () {},
            text: '取消',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              AppButton(
                variant: ButtonVariant.iconOnly,
                icon: 'settings',
                                onPressed: () {},
                              ),
                              const SizedBox(width: 8),
                              AppButton(
                                variant: ButtonVariant.iconOnly,
                                icon: 'settings',
                                onPressed: () {},
                                size: ButtonSize.sm,
                              ),
                              const SizedBox(width: 8),
                              AppButton(
                                variant: ButtonVariant.iconOnly,
                                icon: 'settings',
                                onPressed: () {},
                                size: ButtonSize.lg,
              ),
              const SizedBox(width: 8),
              AppButton(
                variant: ButtonVariant.iconOnly,
                icon: 'refresh',
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              AppButton(
                variant: ButtonVariant.iconOnly,
                icon: 'trash',
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}
