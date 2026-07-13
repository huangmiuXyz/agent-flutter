import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:agent/theme/custom_theme.dart';

const Map<String, IconData> _registry = {
  'sun': LucideIcons.sun,
  'moon': LucideIcons.moon,
  'brush': LucideIcons.brushCleaning,
  'settings': LucideIcons.settings,
  'refresh': LucideIcons.rotateCw,
  'trash': LucideIcons.trash2,
  'square': LucideIcons.square,
  'terminal': LucideIcons.terminal,
  'terminalSquare': LucideIcons.terminalSquare,
  'activity': LucideIcons.activity,
  'x': LucideIcons.x,
  'plus': LucideIcons.plus,
  'arrowRight': LucideIcons.arrowRight,
  'arrowUpRight': LucideIcons.arrowUpRight,
  'search': LucideIcons.search,
  'pencil': LucideIcons.pencil,
  'indentIncrease': LucideIcons.indentIncrease,
  'lightbulb': LucideIcons.lightbulb,
  'scissors': LucideIcons.scissors,
  'copy': LucideIcons.copy,
  'wrapText': LucideIcons.wrapText,
  'alignJustify': LucideIcons.alignJustify,
  'hash': LucideIcons.hash,
  'palette': LucideIcons.palette,
  'fileCode': LucideIcons.fileCode,
  'filePlus': LucideIcons.filePlus,
  'folderPlus': LucideIcons.folderPlus,
  'trash2': LucideIcons.trash2,
  'folderOpen': LucideIcons.folderOpen,
  'clipboardPaste': LucideIcons.clipboardPaste,
  'clipboardType': LucideIcons.clipboardType,
  'delete': LucideIcons.delete,
  'checkSquare2': LucideIcons.checkSquare2,
  'eraser': LucideIcons.eraser,
  'star': LucideIcons.star,
  'home': LucideIcons.home,
  'bell': LucideIcons.bell,
  'file': LucideIcons.file,
  'folder': LucideIcons.folder,
  'layers': LucideIcons.layers,
};

class AppIcon extends ConsumerWidget {
  final String name;
  final double? size;
  final Color? color;

  const AppIcon(this.name, {super.key, this.size, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = _registry[name] ?? LucideIcons.helpCircle;
    return Icon(
      icon,
      size: size,
      color: color ?? CustomTheme.of(context).colors.textPrimary,
    );
  }
}
