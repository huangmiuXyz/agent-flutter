import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const Map<String, IconData> _registry = {
  'sun': LucideIcons.sun200,
  'moon': LucideIcons.moon200,
  'brush': LucideIcons.brushCleaning200,
  'settings': LucideIcons.settings200,
  'refresh': LucideIcons.rotateCw200,
  'trash': LucideIcons.trash2200,
};

class AppIcon extends StatelessWidget {
  final String name;
  final double? size;

  const AppIcon(this.name, {super.key, this.size});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Icon(_registry[name] ?? Icons.error_outline, size: size, color: color);
  }
}
