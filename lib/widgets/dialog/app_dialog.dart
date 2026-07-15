import 'package:flutter/material.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_button.dart';
import 'package:agent/widgets/text/app_text.dart';

/// A theme-aware modal dialog with header, scrollable body, and footer.
///
/// Supports a centered modal variant (default) and can be shown via the
/// static [show] method for convenience.
///
/// ```dart
/// // Quick confirm dialog
/// AppDialog.show(
///   context: context,
///   title: '删除文件',
///   child: AppText('确定要删除该文件吗？此操作不可恢复。'),
///   onOk: () => file.delete(),
/// );
/// ```
class AppDialog extends StatelessWidget {
  final String? title;
  final Widget child;
  final String? okText;
  final String? cancelText;
  final VoidCallback? onOk;
  final VoidCallback? onCancel;
  final bool showFooter;
  final bool showCancel;
  final double? width;

  const AppDialog({
    super.key,
    this.title,
    required this.child,
    this.okText,
    this.cancelText,
    this.onOk,
    this.onCancel,
    this.showFooter = true,
    this.showCancel = true,
    this.width,
  });

  /// Shows the dialog in a modal overlay.
  ///
  /// Returns `true` if the user confirmed, `false` or `null` otherwise.
  static Future<bool?> show({
    required BuildContext context,
    String? title,
    required Widget child,
    String? okText,
    String? cancelText,
    VoidCallback? onOk,
    VoidCallback? onCancel,
    bool showFooter = true,
    bool showCancel = true,
    double? width,
    bool barrierDismissible = true,
  }) {
    final custom = CustomTheme.of(context);
    return showGeneralDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: custom.colors.overlay,
      barrierLabel: 'Dialog',
      transitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => _AppDialogRoot(
        title: title,
        child: child,
        okText: okText,
        cancelText: cancelText,
        onOk: onOk,
        onCancel: onCancel,
        showFooter: showFooter,
        showCancel: showCancel,
        width: width,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AppDialogRoot(
      title: title,
      child: child,
      okText: okText,
      cancelText: cancelText,
      onOk: onOk,
      onCancel: onCancel,
      showFooter: showFooter,
      showCancel: showCancel,
      width: width,
    );
  }
}

/// Internal widget that renders the dialog box with header, body, and footer.
class _AppDialogRoot extends StatelessWidget {
  final String? title;
  final Widget child;
  final String? okText;
  final String? cancelText;
  final VoidCallback? onOk;
  final VoidCallback? onCancel;
  final bool showFooter;
  final bool showCancel;
  final double? width;

  const _AppDialogRoot({
    this.title,
    required this.child,
    this.okText,
    this.cancelText,
    this.onOk,
    this.onCancel,
    this.showFooter = true,
    this.showCancel = true,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final pop = () => Navigator.of(context).pop();

    final effectiveWidth = width ?? custom.controls.dialogWidth;

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: effectiveWidth,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: custom.colors.cardBackground,
            borderRadius: custom.radii.md,
            border: Border.all(color: custom.colors.cardBorder),
            boxShadow: custom.shadows.large,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ---- Header ----
              if (title != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: custom.spacing.sm,
                    vertical: custom.spacing.sm,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: custom.colors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppText(
                          title!,
                          variant: AppTextVariant.body,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      AppButton(
                        icon: 'x',
                        variant: ButtonVariant.iconOnly,
                        size: ButtonSize.sm,
                        onPressed: () {
                          onCancel?.call();
                          pop();
                        },
                      ),
                    ],
                  ),
                ),

              // ---- Body ----
              Flexible(
                child: Padding(
                  padding: EdgeInsets.all(custom.spacing.lg),
                  child: child,
                ),
              ),

              // ---- Footer ----
              if (showFooter)
                Container(
                  padding: EdgeInsets.fromLTRB(
                    custom.spacing.lg,
                    custom.spacing.sm,
                    custom.spacing.sm,
                    custom.spacing.sm,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: custom.colors.border),
                    ),
                    color: custom.colors.background,
                    borderRadius: BorderRadius.vertical(
                      bottom: custom.radii.md.topLeft,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (showCancel)
                        Padding(
                          padding: EdgeInsets.only(right: custom.spacing.sm),
                          child: AppButton(
                            text: cancelText ?? '取消',
                            variant: ButtonVariant.secondary,
                            onPressed: () {
                              onCancel?.call();
                              pop();
                            },
                          ),
                        ),
                      AppButton(
                        text: okText ?? '确认',
                        variant: ButtonVariant.primary,
                        onPressed: () {
                          onOk?.call();
                          pop();
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
