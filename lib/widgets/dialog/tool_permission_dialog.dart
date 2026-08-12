/// 工具权限确认弹窗 — 三选一（本次通过 / 总是运行 / 拒绝）。
///
/// 仅作为非流式场景（无工具卡片可挂，`ToolPermissionRequest.part_id` 为空）的
/// 回退路径；流式会话使用工具卡片上的内联确认按钮（见 ChatMessageItem）。
/// 用户选择后把决定字符串回传给 Rust（`submitToolPermission`）。
library;

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 弹出工具权限确认框。
///
/// 返回决定字符串：`"allow_once"`（本次通过）/ `"always_allow"`（总是运行）/
/// `"deny"`（拒绝）。
///
/// 弹窗被关闭（Esc / 关闭按钮）时同样返回 `"deny"`：任何未明确允许的结果
/// 都视为拒绝，且必须回传决定 —— 否则 Rust 侧挂起的工具调用永远不会恢复。
Future<String> showToolPermissionDialog({
  required BuildContext context,
  required String toolName,
  required String arguments,
}) async {
  final decision = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierLabel: '工具权限确认',
    transitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) =>
        _ToolPermissionDialog(toolName: toolName, arguments: arguments),
  );
  return decision ?? 'deny';
}

class _ToolPermissionDialog extends StatelessWidget {
  const _ToolPermissionDialog({
    required this.toolName,
    required this.arguments,
  });

  final String toolName;
  final String arguments;

  void _decide(BuildContext context, String decision) {
    Navigator.of(context).pop(decision);
  }

  String? get _prettyArguments {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(jsonDecode(arguments));
    } catch (_) {
      return arguments.isEmpty ? null : arguments;
    }
  }

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final pretty = _prettyArguments;

    return Align(
      alignment: Alignment.center,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 480,
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
              // ── Header ──
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
                    AppIcon(
                      'lock',
                      size: 16,
                      color: custom.colors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppText(
                        '工具权限确认',
                        variant: AppTextVariant.body,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    AppIconButton(
                      icon: 'x',
                      size: ButtonSize.sm,
                      tooltip: '关闭（视为拒绝）',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // ── Body ──
              Flexible(
                child: Padding(
                  padding: EdgeInsets.all(custom.spacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        '智能体请求执行以下工具，是否允许？',
                        variant: AppTextVariant.body,
                        color: custom.colors.textPrimary,
                      ),
                      SizedBox(height: custom.spacing.md),
                      // 工具名
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: custom.spacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: custom.colors.panel,
                          borderRadius: custom.radii.sm,
                          border: Border.all(color: custom.colors.cardBorder),
                        ),
                        child: AppText(
                          toolName,
                          variant: AppTextVariant.body,
                          style: TextStyle(
                            fontFamily:
                                custom.typography.fontFamily ??
                                kDefaultFontFamily,
                            color: custom.colors.textPrimary,
                          ),
                        ),
                      ),
                      // 参数预览
                      if (pretty != null) ...[
                        SizedBox(height: custom.spacing.sm),
                        Container(
                          constraints: BoxConstraints(
                            maxHeight: 220,
                            minHeight: 0,
                          ),
                          width: double.infinity,
                          padding: EdgeInsets.all(custom.spacing.sm),
                          decoration: BoxDecoration(
                            color: custom.colors.background,
                            borderRadius: custom.radii.sm,
                            border: Border.all(color: custom.colors.cardBorder),
                          ),
                          child: SingleChildScrollView(
                            child: AppText(
                              pretty,
                              variant: AppTextVariant.caption,
                              style: TextStyle(
                                fontFamily:
                                    custom.typography.fontFamily ??
                                    kDefaultFontFamily,
                                color: custom.colors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: custom.spacing.sm),
                      AppText(
                        '本次通过：仅执行这一次；总是运行：记住此决定，之后直接执行；'
                        '拒绝：仅本次拒绝，不记住',
                        variant: AppTextVariant.caption,
                        color: custom.colors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Footer：三选一 ──
              Container(
                padding: EdgeInsets.fromLTRB(
                  custom.spacing.lg,
                  custom.spacing.sm,
                  custom.spacing.sm,
                  custom.spacing.sm,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: custom.colors.border)),
                  color: custom.colors.background,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppSecondaryButton(
                      text: '拒绝',
                      onPressed: () => _decide(context, 'deny'),
                    ),
                    SizedBox(width: custom.spacing.sm),
                    AppSecondaryButton(
                      text: '本次通过',
                      onPressed: () => _decide(context, 'allow_once'),
                    ),
                    SizedBox(width: custom.spacing.sm),
                    AppPrimaryButton(
                      text: '总是运行',
                      onPressed: () => _decide(context, 'always_allow'),
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
