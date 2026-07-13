import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_button.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Demo page section for showcasing button variants.
class ButtonDemo extends ConsumerWidget {
  const ButtonDemo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = CustomTheme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Primary
        _sectionHeader(context, 'Primary', custom),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppButton(variant: ButtonVariant.primary, onPressed: () {}, text: '主要'),
            AppButton(variant: ButtonVariant.primary, onPressed: () {}, text: '小', size: ButtonSize.sm),
            AppButton(variant: ButtonVariant.primary, onPressed: () {}, text: '中'),
            AppButton(variant: ButtonVariant.primary, onPressed: () {}, text: '大', size: ButtonSize.lg),
          ],
        ),
        const SizedBox(height: 32),

        // Secondary
        _sectionHeader(context, 'Secondary', custom),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppButton(variant: ButtonVariant.secondary, onPressed: () {}, text: '次要'),
            AppButton(variant: ButtonVariant.secondary, onPressed: () {}, text: '小', size: ButtonSize.sm),
            AppButton(variant: ButtonVariant.secondary, onPressed: () {}, text: '中'),
            AppButton(variant: ButtonVariant.secondary, onPressed: () {}, text: '大', size: ButtonSize.lg),
          ],
        ),
        const SizedBox(height: 32),

        // Text
        _sectionHeader(context, 'Text', custom),
        const SizedBox(height: 12),
        AppButton(variant: ButtonVariant.text, onPressed: () {}, text: '文字'),
        const SizedBox(height: 32),

        // Icon only
        _sectionHeader(context, 'Icon Only', custom),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppButton(variant: ButtonVariant.iconOnly, icon: 'settings', onPressed: () {}, size: ButtonSize.sm),
            AppButton(variant: ButtonVariant.iconOnly, icon: 'settings', onPressed: () {}),
            AppButton(variant: ButtonVariant.iconOnly, icon: 'settings', onPressed: () {}, size: ButtonSize.lg),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppButton(variant: ButtonVariant.iconOnly, icon: 'sun', onPressed: () {}),
            AppButton(variant: ButtonVariant.iconOnly, icon: 'moon', onPressed: () {}),
            AppButton(variant: ButtonVariant.iconOnly, icon: 'brush', onPressed: () {}),
            AppButton(variant: ButtonVariant.iconOnly, icon: 'refresh', onPressed: () {}),
            AppButton(variant: ButtonVariant.iconOnly, icon: 'trash', onPressed: () {}),
          ],
        ),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String label, CustomTheme custom) {
    return AppText(label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: custom.colors.textSecondary,
          letterSpacing: 0.5,
        ));
  }
}
