/// Display settings page — form-based overview with breadcrumb navigation.
///
/// Provides a reactive form for display-related settings. Currently includes
/// a font setting row that navigates to the full [FontSettingsPage].
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/settings/pages/font_settings_page.dart';
import 'package:agent/store/theme_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/breadcrumb/app_breadcrumb.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/reactive/form_row.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Display settings page with a reactive form.
///
/// Each row corresponds to a display setting. Clicking the settings button
/// on the font row navigates to the full [FontSettingsPage].
class DisplaySettingsPage extends HookWidget {
  const DisplaySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final showFontSettings = useState(false);
    final store = ThemeStore.instance;
    final currentFont = useExistingSignal(store.fontFamily);

    // Navigate to font detail page
    if (showFontSettings.value) {
      return FontSettingsPage(onBack: () => showFontSettings.value = false);
    }

    return ContentFrame(
      child: SizedBox(
        width: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Breadcrumb ----
            AppBreadcrumb(
              items: [
                AppBreadcrumbItem('设置', onTap: () {}),
                AppBreadcrumbItem('显示设置'),
              ],
            ),
            SizedBox(height: custom.spacing.lg),

            // ---- Title ----
            const AppText('显示设置', variant: AppTextVariant.title),
            SizedBox(height: custom.spacing.lg + 4),

            // ---- Font setting row ----
            FormRow(
              label: '字体',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppText(
                    currentFont.value,
                    variant: AppTextVariant.body,
                    color: custom.colors.textPrimary,
                  ),
                  SizedBox(width: custom.spacing.sm),
                  AppIconButton(
                    icon: 'settings',
                    tooltip: '字体设置',
                    onPressed: () => showFontSettings.value = true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
