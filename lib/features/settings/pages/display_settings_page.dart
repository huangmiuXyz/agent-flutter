/// Display settings page — form-based overview without breadcrumb navigation.
///
/// Provides a form-style overview of display-related settings. Currently
/// includes a font setting row that navigates to the full [FontSettingsPage]
/// via [onFontSettingsTap].
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/store/theme_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/form/app_form_page.dart';
import 'package:agent/widgets/reactive/form_row.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Display settings overview.
///
/// Each row corresponds to a display setting. Clicking the settings button
/// on the font row invokes [onFontSettingsTap] to open the font settings page.
class DisplaySettingsPage extends HookWidget {
  /// Called when the user taps the settings button on the font row.
  final VoidCallback onFontSettingsTap;

  const DisplaySettingsPage({super.key, required this.onFontSettingsTap});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final store = ThemeStore.instance;
    final currentFont = useExistingSignal(store.fontFamily);

    return AppFormPage(
      title: '显示设置',
      children: [
        FormRow(
          label: '字体',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: AppText(
                  currentFont.value,
                  variant: AppTextVariant.body,
                  color: custom.colors.textPrimary,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              SizedBox(width: custom.spacing.sm),
              AppIconButton(
                icon: 'settings',
                tooltip: '字体设置',
                onPressed: onFontSettingsTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
