import 'package:flutter/material.dart';


import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/button/app_text_button.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Demo page section for showcasing button variants.
class ButtonDemo extends StatelessWidget {
  const ButtonDemo({super.key});

  @override
  Widget build(BuildContext context) {
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
            AppPrimaryButton(onPressed: () {}, text: '主要'),
            AppPrimaryButton(onPressed: () {}, text: '小', size: ButtonSize.sm),
            AppPrimaryButton(onPressed: () {}, text: '中'),
            AppPrimaryButton(onPressed: () {}, text: '大', size: ButtonSize.lg),
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
            AppSecondaryButton(onPressed: () {}, text: '次要'),
            AppSecondaryButton(
              onPressed: () {},
              text: '小',
              size: ButtonSize.sm,
            ),
            AppSecondaryButton(onPressed: () {}, text: '中'),
            AppSecondaryButton(
              onPressed: () {},
              text: '大',
              size: ButtonSize.lg,
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Text
        _sectionHeader(context, 'Text', custom),
        const SizedBox(height: 12),
        AppTextButton(onPressed: () {}, text: '文字'),
        const SizedBox(height: 32),

        // Icon only
        _sectionHeader(context, 'Icon Only', custom),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppIconButton(
              icon: 'settings',
              onPressed: () {},
              size: ButtonSize.sm,
            ),
            AppIconButton(icon: 'settings', onPressed: () {}),
            AppIconButton(
              icon: 'settings',
              onPressed: () {},
              size: ButtonSize.lg,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppIconButton(icon: 'sun', onPressed: () {}),
            AppIconButton(icon: 'moon', onPressed: () {}),
            AppIconButton(icon: 'brush', onPressed: () {}),
            AppIconButton(icon: 'refresh', onPressed: () {}),
            AppIconButton(icon: 'trash', onPressed: () {}),
          ],
        ),
      ],
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    String label,
    CustomTheme custom,
  ) {
    return AppText(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: custom.colors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}
