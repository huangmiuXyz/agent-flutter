import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:nanoid/nanoid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/terminal/terminal_widget.dart';

String tabLabel(String shell) {
  final resolved = shell.isNotEmpty
      ? shell
      : resolveShell();
  return resolved.split(RegExp(r'[\\/]')).last;
}

String resolveShell() {
  if (Platform.isWindows) return 'cmd.exe';
  final envShell = Platform.environment['SHELL'];
  if (envShell != null && envShell.isNotEmpty) return envShell;
  return File('/bin/zsh').existsSync() ? '/bin/zsh' : '/bin/bash';
}

List<String> availableShells() {
  if (kIsWeb) return ['/bin/bash'];
  if (!Platform.isWindows) return ['/bin/bash', '/bin/zsh', '/bin/sh'];
  final shells = <String>['cmd.exe'];
  if (Process.runSync('where', ['pwsh.exe']).exitCode == 0) {
    shells.add('pwsh.exe');
  }
  if (File(r'C:\Program Files\Git\bin\bash.exe').existsSync()) {
    shells.add(r'C:\Program Files\Git\bin\bash.exe');
  }
  if (Process.runSync('where', ['wsl']).exitCode == 0) {
    shells.add('wsl.exe');
  }
  return shells;
}

class TabInfo {
  final String id;
  final String shell;
  const TabInfo({required this.id, this.shell = ''});
}

/// A terminal tab bar with multiple terminal instances.
class TerminalTabs extends HookConsumerWidget {
  const TerminalTabs({this.active = true});

  /// Whether the outer tab (Terminal) is currently selected.
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = useState<List<TabInfo>>([TabInfo(id: nanoid(8))]);
    final activeIndex = useState(0);
    final custom = CustomTheme.of(context);

    void addTab(String shell) {
      final id = nanoid(8);
      tabs.value = [...tabs.value, TabInfo(id: id, shell: shell)];
      activeIndex.value = tabs.value.length - 1;
    }

    void closeTab(int index) {
      if (tabs.value.length <= 1) return;
      final newTabs = [...tabs.value]..removeAt(index);
      tabs.value = newTabs;
      if (activeIndex.value >= newTabs.length) {
        activeIndex.value = newTabs.length - 1;
      } else if (activeIndex.value > index) {
        activeIndex.value = activeIndex.value - 1;
      }
    }

    return Column(
      children: [
        Container(
          height: 36,
          color: custom.surfaceContainerLow,
          child: Row(
            children: [
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: tabs.value.length,
                  itemBuilder: (context, index) => TabItem(
                    label: tabLabel(tabs.value[index].shell),
                    active: activeIndex.value == index,
                    onTap: () => activeIndex.value = index,
                    onClose: tabs.value.length > 1
                        ? () => closeTab(index)
                        : null,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.add, size: 16, color: custom.onSurface),
                tooltip: 'New terminal',
                onSelected: addTab,
                itemBuilder: (context) => [
                  for (final shell in availableShells())
                    PopupMenuItem(value: shell, child: Text(shell, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: CustomTheme.of(context).spacingXs),
        Expanded(
          child: IndexedStack(
            index: activeIndex.value,
            children: [
              for (var i = 0; i < tabs.value.length; i++)
                TerminalWidget(
                  key: ValueKey(tabs.value[i].id),
                  id: tabs.value[i].id,
                  shell: tabs.value[i].shell,
                  visible: active && activeIndex.value == i,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single terminal tab header item.
class TabItem extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const TabItem({
    required this.label,
    required this.active,
    required this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? custom.surface : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: active ? custom.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active ? custom.onSurface : custom.onSurfaceVariant,
              ),
            ),
            if (onClose != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClose,
                child: Icon(Icons.close, size: 14, color: custom.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
