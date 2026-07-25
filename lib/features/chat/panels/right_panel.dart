import 'dart:async';
import 'dart:io' show ProcessInfo;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

import 'package:agent/store/session_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/divider/app_divider.dart';
import 'package:agent/widgets/text/app_text.dart';

// ─── 性能数据采集 ───

class _PerformanceSnapshot {
  final DateTime timestamp;
  final double fps;
  final double buildTimeMs;
  final double rasterTimeMs;
  final int frameCount;
  final String memoryMb;

  const _PerformanceSnapshot({
    required this.timestamp,
    required this.fps,
    required this.buildTimeMs,
    required this.rasterTimeMs,
    required this.frameCount,
    required this.memoryMb,
  });

  String toLogLine() {
    final t =
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
    return '$t  '
        'FPS: ${fps.toStringAsFixed(1)}  '
        'Build: ${buildTimeMs.toStringAsFixed(2)}ms  '
        'Raster: ${rasterTimeMs.toStringAsFixed(2)}ms  '
        'Mem: $memoryMb  '
        'Frames: $frameCount';
  }
}

class _PerformanceData {
  // FPS
  int frameCount = 0;
  int lastSecondFrames = 0;
  double currentFps = 0;
  double maxFps = 0;
  double minFps = double.infinity;

  // Frame timing (滑动窗口平均)
  final List<double> _buildTimes = [];
  final List<double> _rasterTimes = [];
  double avgBuildTimeMs = 0;
  double avgRasterTimeMs = 0;
  double maxBuildTimeMs = 0;
  double maxRasterTimeMs = 0;

  // Memory (via dart:io ProcessInfo 或兜底)
  int currentMemoryBytes = 0;
  int peakMemoryBytes = 0;

  // 录制
  bool isRecording = false;
  final List<_PerformanceSnapshot> recordedSnapshots = [];
  DateTime? recordingStarted;

  void recordFrame(double buildMs, double rasterMs) {
    frameCount++;
    _buildTimes.add(buildMs);
    _rasterTimes.add(rasterMs);
    if (_buildTimes.length > 60) _buildTimes.removeAt(0);
    if (_rasterTimes.length > 60) _rasterTimes.removeAt(0);

    avgBuildTimeMs = _buildTimes.reduce((a, b) => a + b) / _buildTimes.length;
    avgRasterTimeMs =
        _rasterTimes.reduce((a, b) => a + b) / _rasterTimes.length;
    if (buildMs > maxBuildTimeMs) maxBuildTimeMs = buildMs;
    if (rasterMs > maxRasterTimeMs) maxRasterTimeMs = rasterMs;
  }

  void tickSecond() {
    final framesThisSecond = frameCount - lastSecondFrames;
    lastSecondFrames = frameCount;
    currentFps = framesThisSecond.toDouble();
    if (currentFps > maxFps) maxFps = currentFps;
    if (currentFps < minFps) minFps = currentFps;
  }

  void updateMemory(int bytes) {
    currentMemoryBytes = bytes;
    if (bytes > peakMemoryBytes) peakMemoryBytes = bytes;
  }

  String get memoryCurrentFormatted {
    if (currentMemoryBytes <= 0) return 'N/A';
    return '${(currentMemoryBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get memoryPeakFormatted {
    if (peakMemoryBytes <= 0) return 'N/A';
    return '${(peakMemoryBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void startRecording() {
    isRecording = true;
    recordingStarted = DateTime.now();
    recordedSnapshots.clear();
  }

  void stopRecording() {
    isRecording = false;
  }

  _PerformanceSnapshot takeSnapshot(String memoryMb) {
    final s = _PerformanceSnapshot(
      timestamp: DateTime.now(),
      fps: currentFps,
      buildTimeMs: avgBuildTimeMs,
      rasterTimeMs: avgRasterTimeMs,
      frameCount: frameCount,
      memoryMb: memoryMb,
    );
    if (isRecording) recordedSnapshots.add(s);
    return s;
  }

  String buildLogText() {
    if (recordedSnapshots.isEmpty) return '(无录制数据)';

    final start = recordedSnapshots.first.timestamp;
    final end = recordedSnapshots.last.timestamp;
    final buf = StringBuffer();
    buf.writeln(
      '=== 性能日志 [${_fmtDt(start)} ~ ${_fmtDt(end)}] ===',
    );
    buf.writeln('共 ${recordedSnapshots.length} 条记录');
    buf.writeln('');
    for (final s in recordedSnapshots) {
      buf.writeln(s.toLogLine());
    }
    buf.writeln('');
    buf.writeln('--- 统计汇总 ---');
    final fpsValues = recordedSnapshots.map((s) => s.fps).toList();
    final buildValues = recordedSnapshots.map((s) => s.buildTimeMs).toList();
    final rasterValues = recordedSnapshots.map((s) => s.rasterTimeMs).toList();
    if (fpsValues.isNotEmpty) {
      buf.writeln(
        'FPS 平均: ${(fpsValues.reduce((a, b) => a + b) / fpsValues.length).toStringAsFixed(1)}',
      );
      buf.writeln('FPS 最低: ${fpsValues.reduce(min).toStringAsFixed(1)}');
      buf.writeln('FPS 最高: ${fpsValues.reduce(max).toStringAsFixed(1)}');
    }
    if (buildValues.isNotEmpty) {
      buf.writeln(
        'Build 平均: ${(buildValues.reduce((a, b) => a + b) / buildValues.length).toStringAsFixed(2)}ms',
      );
      buf.writeln('Raster 平均: ${(rasterValues.reduce((a, b) => a + b) / rasterValues.length).toStringAsFixed(2)}ms');
    }
    return buf.toString();
  }

  static String _fmtDt(DateTime dt) {
    return '${dt.year}-${_p(dt.month)}-${_p(dt.day)} '
        '${_p(dt.hour)}:${_p(dt.minute)}:${_p(dt.second)}';
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}

// ─── Memory Reader ───

int? _tryReadMemoryBytes() {
  try {
    // ProcessInfo 在桌面平台 (macOS/Linux/Windows) 可用
    return ProcessInfo.currentRss;
  } catch (_) {
    return null;
  }
}

// ─── RightPanel ───

/// 右侧性能检测面板
///
/// 实时显示 FPS、帧构建/栅格化耗时、内存占用、会话统计等指标。
/// 支持一键录制一段时间内的性能日志并复制到剪贴板。
class RightPanel extends StatefulWidget {
  const RightPanel({super.key});

  @override
  State<RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<RightPanel>
    with SingleTickerProviderStateMixin {
  final _data = _PerformanceData();
  late Ticker _ticker;
  Timer? _secondTimer;
  Timer? _memTimer;

  // 通过 addTimingsCallback 收集帧 timing
  TimingsCallback? _timingsCallback;

  // UI 刷新节流
  int _uiTickCounter = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();

    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _data.tickSecond();
      if (_data.isRecording) {
        _data.takeSnapshot(_readMemory());
      }
      _safeSetState();
    });

    _memTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final mem = _tryReadMemoryBytes();
      if (mem != null) _data.updateMemory(mem);
    });

    // 注册帧 timing 回调
    _timingsCallback = (List<FrameTiming> timings) {
      for (final t in timings) {
        final buildMs =
            t.buildDuration.inMicroseconds / Duration.microsecondsPerMillisecond;
        final rasterMs =
            t.rasterDuration.inMicroseconds / Duration.microsecondsPerMillisecond;
        _data.recordFrame(buildMs, rasterMs);
      }
    };
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback!);
  }

  @override
  void dispose() {
    if (_timingsCallback != null) {
      SchedulerBinding.instance.removeTimingsCallback(_timingsCallback!);
    }
    _ticker.dispose();
    _secondTimer?.cancel();
    _memTimer?.cancel();
    super.dispose();
  }

  void _onTick(Duration _) {
    // 不需要在每帧都 setState，用节流
    _uiTickCounter++;
    if (_uiTickCounter % 3 == 0 && mounted) {
      setState(() {});
    }
  }

  void _safeSetState() {
    if (mounted) setState(() {});
  }

  String _readMemory() {
    final mem = _tryReadMemoryBytes();
    if (mem != null) {
      _data.updateMemory(mem);
      return _data.memoryCurrentFormatted;
    }
    return 'N/A';
  }

  void _toggleRecording() {
    setState(() {
      if (_data.isRecording) {
        _data.stopRecording();
      } else {
        _data.startRecording();
      }
    });
  }

  Future<void> _copyLogs() async {
    final text = _data.buildLogText();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _data.recordedSnapshots.isEmpty
                ? '暂无录制数据'
                : '已复制 ${_data.recordedSnapshots.length} 条日志',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearLogs() {
    setState(() {
      _data.recordedSnapshots.clear();
      _data.recordingStarted = null;
    });
  }

  // ─── 会话统计 ───
  int get _sessionCount => SessionStore.instance.sessionList.value.length;

  int get _totalMessages {
    int count = 0;
    for (final state in SessionStore.instance.sessions.value.values) {
      count += state.messageOrder.length;
    }
    return count;
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final uptime = DateTime.now().difference(_appStart);

    return Container(
      color: custom.colors.panel,
      child: Column(
        children: [
          _buildHeader(custom),
          const AppDivider(extent: 1, thickness: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(custom.spacing.sm),
              children: [
                _buildFpsCard(custom),
                SizedBox(height: custom.spacing.sm),
                _buildMemoryCard(custom),
                SizedBox(height: custom.spacing.sm),
                _buildSessionCard(custom),
                SizedBox(height: custom.spacing.sm),
                _buildUptimeCard(custom, uptime),
                SizedBox(height: custom.spacing.sm),
                _buildRecordingCard(custom),
                if (_data.isRecording || _data.recordedSnapshots.isNotEmpty) ...[
                  SizedBox(height: custom.spacing.sm),
                  _buildLogPreview(custom),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(CustomTheme custom) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: custom.spacing.sm,
        vertical: custom.spacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: custom.colors.separator),
        ),
      ),
      child: Row(
        children: [
          AppText(
            '⚡ 性能面板',
            variant: AppTextVariant.body,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          AppIconButton(
            icon: _data.isRecording ? 'stopCircle' : 'activity',
            size: ButtonSize.sm,
            tooltip: _data.isRecording ? '停止录制' : '开始录制',
            onPressed: _toggleRecording,
            backgroundColor:
                _data.isRecording ? custom.colors.danger.withValues(alpha: 0.2) : null,
          ),
          SizedBox(width: custom.spacing.xs),
          AppIconButton(
            icon: 'copy',
            size: ButtonSize.sm,
            tooltip: '复制日志',
            onPressed: _data.recordedSnapshots.isEmpty ? null : _copyLogs,
          ),
          SizedBox(width: custom.spacing.xs),
          AppIconButton(
            icon: 'trash2',
            size: ButtonSize.sm,
            tooltip: '清除日志',
            onPressed: _data.recordedSnapshots.isEmpty ? null : _clearLogs,
          ),
        ],
      ),
    );
  }

  Color _fpsColor(double fps) {
    if (fps >= 55) return Colors.green;
    if (fps >= 30) return Colors.orange;
    return Colors.red;
  }

  Widget _buildLabel(String text) {
    return AppText(
      text,
      variant: AppTextVariant.caption,
      style: const TextStyle(fontWeight: FontWeight.w500),
    );
  }

  Widget _buildFpsCard(CustomTheme custom) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('📊 帧率'),
          SizedBox(height: custom.spacing.xs),
          _MetricRow(
            label: 'FPS',
            value: _data.frameCount > 0 && _data.currentFps > 0
                ? _data.currentFps.toStringAsFixed(1)
                : '等待数据…',
            valueColor: _data.frameCount > 0
                ? _fpsColor(_data.currentFps)
                : custom.colors.textSecondary,
          ),
          SizedBox(height: 2),
          _MetricRow(
            label: '峰值',
            value: _data.maxFps > 0
                ? _data.maxFps.toStringAsFixed(1)
                : '—',
          ),
          SizedBox(height: 2),
          _MetricRow(
            label: '最低',
            value: _data.minFps < double.infinity
                ? _data.minFps.toStringAsFixed(1)
                : '—',
          ),
          SizedBox(height: 2),
          _MetricRow(
            label: '构建',
            value: _data.frameCount > 0
                ? '${_data.avgBuildTimeMs.toStringAsFixed(2)} ms'
                : '—',
          ),
          SizedBox(height: 2),
          _MetricRow(
            label: '栅格化',
            value: _data.frameCount > 0
                ? '${_data.avgRasterTimeMs.toStringAsFixed(2)} ms'
                : '—',
          ),
          SizedBox(height: 2),
          _MetricRow(
            label: '总帧数',
            value: '${_data.frameCount}',
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(CustomTheme custom) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('💾 内存'),
          SizedBox(height: custom.spacing.xs),
          _MetricRow(label: '当前', value: _data.memoryCurrentFormatted),
          SizedBox(height: 2),
          _MetricRow(label: '峰值', value: _data.memoryPeakFormatted),
        ],
      ),
    );
  }

  Widget _buildSessionCard(CustomTheme custom) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('🖥️ 会话'),
          SizedBox(height: custom.spacing.xs),
          _MetricRow(label: '会话数', value: '$_sessionCount'),
          SizedBox(height: 2),
          _MetricRow(label: '消息数', value: '$_totalMessages'),
          SizedBox(height: 2),
          _MetricRow(
            label: '流式中',
            value:
                '${SessionStore.instance.streamingSessionIds.value.length}',
          ),
        ],
      ),
    );
  }

  Widget _buildUptimeCard(CustomTheme custom, Duration uptime) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('⏱️ 运行时间'),
          SizedBox(height: custom.spacing.xs),
          _MetricRow(
            label: '面板',
            value: _fmtDuration(
              DateTime.now().difference(_panelStart),
            ),
          ),
          SizedBox(height: 2),
          _MetricRow(
            label: '应用',
            value: _fmtDuration(uptime),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingCard(CustomTheme custom) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildLabel('📝 录制'),
              if (_data.isRecording)
                Container(
                  margin: EdgeInsets.only(left: custom.spacing.sm),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                ),
            ],
          ),
          SizedBox(height: custom.spacing.xs),
          _MetricRow(
            label: '状态',
            value: _data.isRecording ? '录制中…' : '空闲',
            valueColor: _data.isRecording ? Colors.red : null,
          ),
          SizedBox(height: 2),
          _MetricRow(label: '条目', value: '${_data.recordedSnapshots.length}'),
          if (_data.recordingStarted != null) ...[
            SizedBox(height: 2),
            _MetricRow(
              label: '时长',
              value: _fmtDuration(
                DateTime.now().difference(_data.recordingStarted!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogPreview(CustomTheme custom) {
    final logs = _data.buildLogText();
    final maxLines = 8;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('日志预览'),
          SizedBox(height: custom.spacing.xs),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(custom.spacing.xs),
            decoration: BoxDecoration(
              color: custom.colors.panelElevated,
              borderRadius: custom.radii.xs,
            ),
            child: AppText(
              logs.length > 500 ? '${logs.substring(0, 500)}...' : logs,
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 工具 ───

  String _fmtDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static final DateTime _appStart = DateTime.now();
  final DateTime _panelStart = DateTime.now();
}

// ─── 小部件 ───

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(custom.spacing.sm),
      decoration: BoxDecoration(
        color: custom.colors.cardBackground,
        borderRadius: custom.radii.sm,
        border: Border.all(color: custom.colors.cardBorder),
      ),
      child: child,
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MetricRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: AppText(
            label,
            variant: AppTextVariant.caption,
            color: custom.colors.textSecondary,
          ),
        ),
        Expanded(
          child: AppText(
            value,
            variant: AppTextVariant.caption,
            color: valueColor ?? custom.colors.textPrimary,
            style: const TextStyle(fontFamily: 'JetBrainsMono'),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
