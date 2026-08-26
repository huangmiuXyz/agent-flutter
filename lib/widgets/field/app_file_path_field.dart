/// 文件/目录路径选择字段 — 文本输入框 + 选择按钮。
///
/// 用法：
/// ```dart
/// AppFilePathField(
///   controller: myController,
///   label: '工作目录',
///   placeholder: '选择或输入路径',
///   pickerType: PickerType.directory,
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'package:agent/services/mobile_work_dir.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/utils/platform.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 文件选择类型。
enum PickerType {
  /// 选择文件
  file,

  /// 选择目录
  directory,
}

/// 带"选择…"按钮的路径输入字段。
///
/// 标签（若有）在输入框上方，输入框与按钮在同一行且垂直居中对齐。
class AppFilePathField extends StatelessWidget {
  /// 文本控制器。
  final TextEditingController controller;

  /// 字段标签（显示在输入框上方）。
  final String? label;

  /// 占位文本。
  final String? placeholder;

  /// 选择器类型（文件或目录），默认为目录。
  final PickerType pickerType;

  /// 是否禁用。
  final bool enabled;

  /// 文本变化回调（输入 + 文件选择器选中后均触发）。
  final ValueChanged<String>? onChanged;

  const AppFilePathField({
    super.key,
    required this.controller,
    this.label,
    this.placeholder,
    this.pickerType = PickerType.directory,
    this.enabled = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Padding(
            padding: EdgeInsets.only(bottom: custom.spacing.xs),
            child: AppText(
              label!,
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
            ),
          ),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: AppField(
                controller: controller,
                placeholder: placeholder,
                icon: 'folderOpen',
                enabled: enabled,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 8),
            AppSecondaryButton(
              text: '选择…',
              disabled: !enabled,
              onPressed: enabled ? () => _pick(context) : null,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    try {
      // 移动端目录选择：SAF 选中目录无法直接读（std::fs 限制），
      // 导入副本到应用工作目录，成功后回填导入路径
      if (isMobilePlatform && pickerType == PickerType.directory) {
        final imported = await MobileWorkDirService.instance.pickAndImport();
        if (imported == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: AppText('无法读取所选目录（Android 存储限制）')),
            );
          }
          return;
        }
        controller.text = imported;
        onChanged?.call(controller.text);
        return;
      }

      final String? result;
      if (pickerType == PickerType.directory) {
        result = await FilePicker.getDirectoryPath();
      } else {
        final files = await FilePicker.pickFiles();
        result = files.isEmpty ? null : files.first.path;
      }
      if (result != null && context.mounted) {
        controller.text = result.replaceAll('\\', '/');
        onChanged?.call(controller.text);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText('选择失败: $e')));
      }
    }
  }
}
