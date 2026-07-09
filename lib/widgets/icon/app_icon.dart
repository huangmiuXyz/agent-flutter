import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:agent/theme/provider.dart';

const Map<String, Map<int, IconData>> _registry = {
  'sun': {0: LucideIcons.sun, 100: LucideIcons.sun100, 200: LucideIcons.sun200, 300: LucideIcons.sun300, 400: LucideIcons.sun400, 500: LucideIcons.sun500, 600: LucideIcons.sun600},
  'moon': {0: LucideIcons.moon, 100: LucideIcons.moon100, 200: LucideIcons.moon200, 300: LucideIcons.moon300, 400: LucideIcons.moon400, 500: LucideIcons.moon500, 600: LucideIcons.moon600},
  'brush': {0: LucideIcons.brushCleaning, 100: LucideIcons.brushCleaning100, 200: LucideIcons.brushCleaning200, 300: LucideIcons.brushCleaning300, 400: LucideIcons.brushCleaning400, 500: LucideIcons.brushCleaning500, 600: LucideIcons.brushCleaning600},
  'settings': {0: LucideIcons.settings, 100: LucideIcons.settings100, 200: LucideIcons.settings200, 300: LucideIcons.settings300, 400: LucideIcons.settings400, 500: LucideIcons.settings500, 600: LucideIcons.settings600},
  'refresh': {0: LucideIcons.rotateCw, 100: LucideIcons.rotateCw100, 200: LucideIcons.rotateCw200, 300: LucideIcons.rotateCw300, 400: LucideIcons.rotateCw400, 500: LucideIcons.rotateCw500, 600: LucideIcons.rotateCw600},
  'trash': {0: LucideIcons.trash2, 100: LucideIcons.trash2100, 200: LucideIcons.trash2200, 300: LucideIcons.trash2300, 400: LucideIcons.trash2400, 500: LucideIcons.trash2500, 600: LucideIcons.trash2600},
  'square': {0: LucideIcons.square, 100: LucideIcons.square100, 200: LucideIcons.square200, 300: LucideIcons.square300, 400: LucideIcons.square400, 500: LucideIcons.square500, 600: LucideIcons.square600},
  'terminal': {0: LucideIcons.terminal, 100: LucideIcons.terminal100, 200: LucideIcons.terminal200, 300: LucideIcons.terminal300, 400: LucideIcons.terminal400, 500: LucideIcons.terminal500, 600: LucideIcons.terminal600},
  'activity': {0: LucideIcons.activity, 100: LucideIcons.activity100, 200: LucideIcons.activity200, 300: LucideIcons.activity300, 400: LucideIcons.activity400, 500: LucideIcons.activity500, 600: LucideIcons.activity600},
};

class AppIcon extends ConsumerWidget {
  final String name;
  final double? size;
  final Color? color;

  const AppIcon(this.name, {super.key, this.size, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thickness = ref.watch(themeProvider.select((c) => c.iconThickness));
    final icon = _registry[name]?[thickness] ?? Icons.error_outline;
    return Icon(
      icon,
      size: size,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }
}
