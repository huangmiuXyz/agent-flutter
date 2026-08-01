import 'package:flutter/material.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/icon/app_icon.dart';
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
  final EdgeInsetsGeometry? bodyPadding;
  final bool compactHeader;
  final AlignmentGeometry alignment;

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
    this.bodyPadding,
    this.compactHeader = false,
    this.alignment = Alignment.center,
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
    EdgeInsetsGeometry? bodyPadding,
    bool compactHeader = false,
    bool barrierDismissible = true,
    AlignmentGeometry alignment = Alignment.center,
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
        okText: okText,
        cancelText: cancelText,
        onOk: onOk,
        onCancel: onCancel,
        showFooter: showFooter,
        showCancel: showCancel,
        width: width,
        bodyPadding: bodyPadding,
        compactHeader: compactHeader,
        alignment: alignment,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AppDialogRoot(
      title: title,
      okText: okText,
      cancelText: cancelText,
      onOk: onOk,
      onCancel: onCancel,
      showFooter: showFooter,
      showCancel: showCancel,
      width: width,
      bodyPadding: bodyPadding,
      compactHeader: compactHeader,
      alignment: alignment,
      child: child,
    );
  }
}

/// Internal widget that renders the dialog box with header, body, and footer.
///
/// The header can be dragged to move the dialog around the screen.
class _AppDialogRoot extends StatefulWidget {
  final String? title;
  final Widget child;
  final String? okText;
  final String? cancelText;
  final VoidCallback? onOk;
  final VoidCallback? onCancel;
  final bool showFooter;
  final bool showCancel;
  final double? width;
  final EdgeInsetsGeometry? bodyPadding;
  final bool compactHeader;
  final AlignmentGeometry alignment;

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
    this.bodyPadding,
    this.compactHeader = false,
    this.alignment = Alignment.center,
  });

  static const double _maxHeightFactor = 0.9; // 90% of viewport height

  @override
  State<_AppDialogRoot> createState() => _AppDialogRootState();
}

class _AppDialogRootState extends State<_AppDialogRoot> {
  /// 头部拖拽累计位移
  Offset _dragOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final w = widget;

    final effectiveWidth = w.width ?? custom.controls.dialogWidth;

    return Align(
      alignment: w.alignment,
      child: Transform.translate(
        offset: _dragOffset,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: effectiveWidth,
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(context).size.height *
                  _AppDialogRoot._maxHeightFactor,
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
                // ---- Header (draggable) ----
                if (w.title != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) {
                      setState(() => _dragOffset += details.delta);
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.move,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: custom.spacing.sm,
                          vertical: w.compactHeader ? 4 : custom.spacing.sm,
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
                                w.title!,
                                variant: w.compactHeader
                                    ? AppTextVariant.caption
                                    : AppTextVariant.body,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (w.compactHeader)
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  tooltip: '关闭',
                                  icon: AppIcon(
                                    'x',
                                    size: 14,
                                    color: custom.colors.textPrimary,
                                  ),
                                  onPressed: () {
                                    widget.onCancel?.call();
                                    Navigator.of(context).pop(false);
                                  },
                                ),
                              )
                            else
                              AppIconButton(
                                icon: 'x',
                                size: ButtonSize.sm,
                                onPressed: () {
                                  widget.onCancel?.call();
                                  Navigator.of(context).pop(false);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ---- Body ----
                Flexible(
                  child: Padding(
                    padding: w.bodyPadding ?? EdgeInsets.all(custom.spacing.lg),
                    child: w.child,
                  ),
                ),

                // ---- Footer ----
                if (w.showFooter)
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
                        if (w.showCancel)
                          Padding(
                            padding: EdgeInsets.only(right: custom.spacing.sm),
                            child: AppSecondaryButton(
                              text: w.cancelText ?? '取消',
                              onPressed: () {
                                try {
                                  w.onCancel?.call();
                                } finally {
                                  Navigator.of(context).pop(false);
                                }
                              },
                            ),
                          ),
                        AppPrimaryButton(
                          text: w.okText ?? '确认',
                          onPressed: () {
                            try {
                              w.onOk?.call();
                            } finally {
                              Navigator.of(context).pop(true);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
