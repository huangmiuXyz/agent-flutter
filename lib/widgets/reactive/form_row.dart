import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/text/app_text.dart';

/// A horizontal form row that places [label] on the left and [child] (the
/// form control) on the right, each taking **50%** of the row width.
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

    return Padding(
      padding: EdgeInsets.symmetric(vertical: custom.spacing.xs),
      child: Row(
        children: [
          // ── Label (50%) ──
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppText(
                label,
                variant: AppTextVariant.caption,
                color: custom.colors.textSecondary,
              ),
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
