import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agent/features/chat/chat_fleather.dart';
import 'package:agent/services/llm_providers.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/utils/layout_utils.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/select/panel_selector.dart';
import 'package:agent/widgets/text/app_text.dart';

class ChatInput extends ConsumerWidget {
  const ChatInput({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = CustomTheme.of(context);
    final physicalHeight = 130.0 / MediaQuery.of(context).devicePixelRatio;
    final readingWidth = ref.watch(readingWidthProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        custom.spacing.sm,
        custom.spacing.xs,
        custom.spacing.sm,
        custom.spacing.sm,
      ),
      child: SizedBox(
        width: readingWidth,
        height: physicalHeight,
        child: Column(
          children: [
            const Expanded(child: ChatFleather()),
            SizedBox(
              height: custom.spacing.lg,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Spacer(),
                  const _ConfigBar(),
                  SizedBox(width: custom.spacing.xs),
                  AppIconButton(
                    icon: 'arrowUpRight',
                    size: ButtonSize.sm,
                    backgroundColor: custom.colors.hover,
                    onPressed: () {
                      // TODO: Send message
                    },
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

/// 配置栏 — 提供商/模型选择
class _ConfigBar extends ConsumerWidget {
  const _ConfigBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = CustomTheme.of(context);
    final currentProvider = ref.watch(currentProviderProvider);
    final currentModel = ref.watch(currentModelProvider);
    final providersAsync = ref.watch(providersListProvider);
    final modelsAsync = ref.watch(modelsListProvider);

    final selectors = <Widget>[
      providersAsync.when(
        loading: () => _buildChipPlaceholder(context, '选择提供商'),
        error: (_, _) => _buildChipPlaceholder(context, '选择提供商'),
        data: (providers) => PanelSelector<String>(
          value: currentProvider.isEmpty ? null : currentProvider,
          placeholder: '选择提供商',
          options: providers
              .map(
                (p) => PanelSelectorOption(
                  value: p.name,
                  label: p.displayName ?? p.name,
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) {
              ref.read(currentProviderProvider.notifier).select(val);
              ref.read(currentModelProvider.notifier).select('');
            }
          },
        ),
      ),
      if (currentProvider.isNotEmpty)
        modelsAsync.when(
          loading: () => _buildChipPlaceholder(context, '选择模型'),
          error: (_, _) => _buildChipPlaceholder(context, '选择模型'),
          data: (models) => PanelSelector<String>(
            value: currentModel.isEmpty ? null : currentModel,
            placeholder: '选择模型',
            options: models
                .map((m) => PanelSelectorOption(value: m, label: m))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                ref.read(currentModelProvider.notifier).select(val);
              }
            },
          ),
        ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < selectors.length; i++) ...[
          if (i > 0) SizedBox(width: custom.spacing.xs),
          selectors[i],
        ],
      ],
    );
  }

  Widget _buildChipPlaceholder(BuildContext context, String text) {
    final custom = CustomTheme.of(context);
    return AppText(
      text,
      variant: AppTextVariant.caption,
      color: custom.colors.textSecondary,
    );
  }
}
