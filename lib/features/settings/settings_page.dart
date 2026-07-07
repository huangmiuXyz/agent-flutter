import 'package:flutter/material.dart';

import '../../widgets/text/app_text.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: AppText(
        'Settings Page',
        variant: AppTextVariant.h2,
      ),
    );
  }
}
