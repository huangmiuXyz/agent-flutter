import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/switch/app_switch.dart';
import 'package:agent/widgets/text/app_text.dart';

/// Demo page section for showcasing the Switch component.
class SwitchDemo extends HookConsumerWidget {
  const SwitchDemo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = CustomTheme.of(context);

    // Controllable switch states
    final switch1 = useState(true);
    final switch2 = useState(false);
    final switch3 = useState(true);
    final switch4 = useState(false);
    final switch5 = useState(true);
    final switch6 = useState(false);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // --- Size variants ---
        _sectionHeader(context, '尺寸变体 (Size Variants)', custom),
        const SizedBox(height: 12),
        Wrap(
          spacing: 24,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppSwitch(value: true, size: SwitchSize.sm),
            AppSwitch(value: false, size: SwitchSize.sm),
            AppSwitch(value: true, size: SwitchSize.md),
            AppSwitch(value: false, size: SwitchSize.md),
            AppSwitch(value: true, size: SwitchSize.lg),
            AppSwitch(value: false, size: SwitchSize.lg),
          ],
        ),
        const SizedBox(height: 32),

        // --- Interactive ---
        _sectionHeader(context, '交互 (Interactive)', custom),
        const SizedBox(height: 12),
        Wrap(
          spacing: 24,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppSwitch(
              value: switch1.value,
              onChanged: (v) => switch1.value = v,
              size: SwitchSize.sm,
            ),
            AppSwitch(
              value: switch2.value,
              onChanged: (v) => switch2.value = v,
              size: SwitchSize.md,
            ),
            AppSwitch(
              value: switch3.value,
              onChanged: (v) => switch3.value = v,
              size: SwitchSize.lg,
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppText(
          '当前状态: ${switch1.value}, ${switch2.value}, ${switch3.value}',
          variant: AppTextVariant.caption,
          color: custom.colors.textSecondary,
        ),
        const SizedBox(height: 32),

        // --- With label ---
        _sectionHeader(context, '带标签 (With Label)', custom),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppSwitch(
                value: switch4.value,
                onChanged: (v) => switch4.value = v,
                label: '开启通知',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppSwitch(
                value: switch5.value,
                onChanged: (v) => switch5.value = v,
                label: '夜间模式',
              ),
            ),
            AppSwitch(
              value: switch6.value,
              onChanged: (v) => switch6.value = v,
              label: '自动更新',
            ),
          ],
        ),
        const SizedBox(height: 32),

        // --- Disabled ---
        _sectionHeader(context, '禁用状态 (Disabled)', custom),
        const SizedBox(height: 12),
        Wrap(
          spacing: 24,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const AppSwitch(value: true, disabled: true),
            const AppSwitch(value: false, disabled: true),
            const AppSwitch(
              value: true,
              disabled: true,
              label: '已禁用的开关',
            ),
          ],
        ),
        const SizedBox(height: 32),

        // --- All combinations ---
        _sectionHeader(context, '全部组合 (All Combinations)', custom),
        const SizedBox(height: 12),
        _buildCombinationTable(custom),
      ],
    );
  }

  Widget _buildCombinationTable(CustomTheme custom) {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(80),
        1: FixedColumnWidth(80),
        2: FixedColumnWidth(80),
      },
      border: TableBorder.all(color: custom.colors.borderSubtle, width: 0.5),
      children: [
        // Header row
        TableRow(
          children: [
            _tableCell('尺寸/状态', custom.colors.textSecondary, isHeader: true),
            _tableCell('开启', custom.colors.textSecondary, isHeader: true),
            _tableCell('关闭', custom.colors.textSecondary, isHeader: true),
          ],
        ),
        // SM
        TableRow(
          children: [
            _tableCell('SM', custom.colors.textPrimary),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AppSwitch(value: true, size: SwitchSize.sm),
              ),
            ),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AppSwitch(value: false, size: SwitchSize.sm),
              ),
            ),
          ],
        ),
        // MD
        TableRow(
          children: [
            _tableCell('MD', custom.colors.textPrimary),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AppSwitch(value: true, size: SwitchSize.md),
              ),
            ),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AppSwitch(value: false, size: SwitchSize.md),
              ),
            ),
          ],
        ),
        // LG
        TableRow(
          children: [
            _tableCell('LG', custom.colors.textPrimary),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AppSwitch(value: true, size: SwitchSize.lg),
              ),
            ),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AppSwitch(value: false, size: SwitchSize.lg),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tableCell(String text, Color color, {bool isHeader = false}) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Center(
          child: AppText(
            text,
            variant: AppTextVariant.caption,
            color: color,
            style: TextStyle(
              fontWeight: isHeader ? FontWeight.w600 : null,
            ),
          ),
        ),
      ),
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
