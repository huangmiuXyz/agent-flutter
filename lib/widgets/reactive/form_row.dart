import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/utils/platform.dart';
import 'package:agent/widgets/text/app_text.dart';

/// A horizontal form row that places [label] on the left and [child] (the
/// form control) on the right, each taking **50%** of the row width.
///
/// On narrow/mobile screens the two halves get too cramped (fixed-size
/// controls like sliders overflow), so the row falls back to a vertical
/// layout (label above, control full-width below) to avoid horizontal
/// overflow.
///
/// The label style matches [AppField] (caption + secondary color) so the
/// horizontal row pattern and the vertical field pattern share the same
/// label look.
///
/// Usage:
/// ```dart
/// FormRow(
///   label: 'Name',
///   child: ReactiveAppField(formControlName: 'name'),
/// )
/// ```
class FormRow extends StatelessWidget {
  /// Label text displayed on the left side.
  final String label;

  /// The form field widget displayed on the right side.
  final Widget child;

  const FormRow({
    super.key,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    final labelWidget = AppText(
      label,
      variant: AppTextVariant.caption,
      color: custom.colors.textSecondary,
    );

    // 移动端/窄屏：50/50 分栏会让固定宽度控件（如 Slider）横向溢出，
    // 改为垂直排布（label 在上、控件通栏在下）。
    if (isMobilePlatform) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: custom.spacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labelWidget,
            SizedBox(height: custom.spacing.sm),
            SizedBox(width: double.infinity, child: child),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: custom.spacing.xs),
      child: Row(
        children: [
          // ── Label (50%) ──
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: labelWidget,
            ),
          ),
          SizedBox(width: custom.spacing.md),
          // ── Field (50%, right-aligned) ──
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
