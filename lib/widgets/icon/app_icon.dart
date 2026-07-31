import 'package:flutter/material.dart';
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
  'type': LucideIcons.type,
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
  'mousePointer2': LucideIcons.mousePointer2,
  'chevronRight': LucideIcons.chevronRight,
  'chevronDown': LucideIcons.chevronDown,
  'play': LucideIcons.play,
  'stopCircle': LucideIcons.stopCircle,
  'gauge': LucideIcons.gauge,
  'timer': LucideIcons.timer,
  'hardDrive': LucideIcons.hardDrive,
  'eye': LucideIcons.eye,
  'eyeOff': LucideIcons.eyeOff,
  'key': LucideIcons.key,
  'mail': LucideIcons.mail,
  'user': LucideIcons.user,
  'lock': LucideIcons.lock,
  'check': LucideIcons.check,
  'alertCircle': LucideIcons.alertCircle,
  'info': LucideIcons.info,
  'move': LucideIcons.move,
  'atSign': LucideIcons.atSign,
  'cpu': LucideIcons.cpu,
  'server': LucideIcons.server,
  'puzzle': LucideIcons.puzzle,
  'robot': LucideIcons.bot,
};

class AppIcon extends StatelessWidget {
  final String name;
  final double? size;
  final Color? color;

  const AppIcon(this.name, {super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final icon = _registry[name];
    assert(
      icon != null,
      'AppIcon: "$name" is not registered in _registry. '
      'Add it or use a valid icon name.',
    );
    return Icon(
      icon ?? LucideIcons.helpCircle,
      size: size,
      color: color ?? CustomTheme.of(context).colors.textPrimary,
    );
  }
}
