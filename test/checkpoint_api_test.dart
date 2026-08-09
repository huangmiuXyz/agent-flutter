import 'package:flutter_test/flutter_test.dart';

import 'package:agent/rust_bridge/api/checkpoints.dart' as api;
import 'package:agent/rust_bridge/frb_generated.dart' as frb;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('listCheckpointPaths 返回已有检查点', () async {
    await frb.RustLib.init();
    final paths = await api.listCheckpointPaths(
      dbPath: '../agent-flutter-cli/data/data',
    );
    // ignore: avoid_print
    print('listCheckpointPaths => $paths');
    expect(paths, isNotEmpty);
  });

  test('listCheckpoints 按 workDir 查询', () async {
    final paths = await api.listCheckpointPaths(
      dbPath: '../agent-flutter-cli/data/data',
    );
    if (paths.isEmpty) return;
    final cps = await api.listCheckpoints(
      dbPath: '../agent-flutter-cli/data/data',
      workDir: paths.first.workDir,
    );
    // ignore: avoid_print
    print('listCheckpoints(${paths.first.workDir}) => ${cps.length} 条');
    expect(cps, isNotEmpty);
  });
}
