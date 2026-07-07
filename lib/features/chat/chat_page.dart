import 'package:flutter/material.dart';

import '../../widgets/button/app_button.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          AppButton(
            variant: ButtonVariant.primary,
            onPressed: () {},
            text: '发送',
          ),
          const SizedBox(height: 8),
          AppButton(
            variant: ButtonVariant.primary,
            onPressed: () {},
            text: '发送',
            size: ButtonSize.sm,
          ),
          const SizedBox(height: 8),
          AppButton(
            variant: ButtonVariant.primary,
            onPressed: () {},
            text: '发送',
            size: ButtonSize.lg,
          ),
          const SizedBox(height: 8),
          AppButton(
            variant: ButtonVariant.secondary,
            onPressed: () {},
            text: '取消',
          ),
          const SizedBox(height: 8),
          AppButton(
            variant: ButtonVariant.text,
            onPressed: () {},
            text: '取消',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              AppButton(
                variant: ButtonVariant.iconOnly,
                icon: Icons.settings,
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              AppButton(
                variant: ButtonVariant.iconOnly,
                icon: Icons.settings,
                onPressed: () {},
                size: ButtonSize.sm,
              ),
              const SizedBox(width: 8),
              AppButton(
                variant: ButtonVariant.iconOnly,
                icon: Icons.settings,
                onPressed: () {},
                size: ButtonSize.lg,
              ),
              const SizedBox(width: 8),
              AppButton(
                variant: ButtonVariant.iconOnly,
                icon: Icons.refresh,
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              AppButton(
                variant: ButtonVariant.iconOnly,
                icon: Icons.delete_outline,
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}
