import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';

/// FPS tracker using [SchedulerBinding.addTimingsCallback] + periodic timer.
class _FpsTracker {
  VoidCallback? onUpdate;

  int _frameCount = 0;
  double _currentFps = 0.0;
  double _currentFrameTimeMs = 0.0;
  Timer? _timer;

  // Frame-timing accumulators from the engine.
  int _totalBuildUs = 0;
  int _totalRasterUs = 0;
  int _timingCount = 0;

  // The callback reference we pass to add/removeTimingsCallback.
  void _onTimingsRef(List<FrameTiming> timings) {
    _frameCount += timings.length;
    for (final t in timings) {
      _totalBuildUs += t.buildDuration.inMicroseconds;
      _totalRasterUs += t.rasterDuration.inMicroseconds;
    }
    _timingCount += timings.length;
  }

  void start() {
    SchedulerBinding.instance.addTimingsCallback(_onTimingsRef);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _currentFps = _frameCount.toDouble();
      _frameCount = 0;

      if (_timingCount > 0) {
        _currentFrameTimeMs =
            (_totalBuildUs + _totalRasterUs) / _timingCount / 1000.0;
      } else {
        _currentFrameTimeMs = 0;
      }
      _totalBuildUs = 0;
      _totalRasterUs = 0;
      _timingCount = 0;

      onUpdate?.call();
    });
  }

  void stop() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimingsRef);
    _timer?.cancel();
    _timer = null;
    _frameCount = 0;
    _totalBuildUs = 0;
    _totalRasterUs = 0;
    _timingCount = 0;
  }

  double get fps => _currentFps;
  double get frameTimeMs => _currentFrameTimeMs;

  void dispose() => stop();
}

/// A compact performance monitor widget that displays FPS and memory usage.
class PerformanceMonitor extends HookConsumerWidget {
  const PerformanceMonitor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = CustomTheme.of(context);

    // ── FPS tracker lifecycle ──
    final tracker = useMemoized(() => _FpsTracker());
    final fps = useState(0.0);
    final frameTime = useState(0.0);

    useEffect(() {
      tracker.onUpdate = () {
        fps.value = tracker.fps;
        frameTime.value = tracker.frameTimeMs;
      };
      tracker.start();
      return () => tracker.dispose();
    }, [tracker]);

    // ── Memory polling timer ──
    final memUsed = useState(0);

    useEffect(() {
      memUsed.value = _currentRssMb();
      final timer = Timer.periodic(const Duration(seconds: 2), (_) {
        memUsed.value = _currentRssMb();
      });
      return () => timer.cancel();
    }, []);

    // ── Gauge colour helper ──
    Color gaugeColor(double value, double warn, double critical) {
      if (value >= critical) return custom.colors.danger;
      if (value >= warn) return custom.colors.warning;
      return custom.colors.accent;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader(context, '性能监控', custom),
        const SizedBox(height: 16),

        // FPS
        _MetricCard(
          icon: 'gauge',
          label: 'FPS',
          value: fps.value.toStringAsFixed(1),
          unit: 'fps',
          color: gaugeColor(fps.value, 30, 20),
          barValue: (fps.value / 120).clamp(0.0, 1.0),
        ),
        const SizedBox(height: 8),

        // Frame time
        _MetricCard(
          icon: 'timer',
          label: '帧耗时',
          value: frameTime.value.toStringAsFixed(1),
          unit: 'ms',
          color: gaugeColor(60 / (frameTime.value + 0.01), 16, 33),
          barValue: (frameTime.value / 50).clamp(0.0, 1.0),
        ),
        const SizedBox(height: 8),

        // Memory usage (only when available)
        if (memUsed.value > 0)
          _MetricCard(
            icon: 'hardDrive',
            label: '内存使用',
            value: '${memUsed.value}',
            unit: 'MB',
            color: gaugeColor(
              memUsed.value.toDouble(),
              0, // no warning threshold
              0, // no critical threshold
            ),
            barValue: 0,
          ),

        const SizedBox(height: 24),
        _sectionHeader(context, '引擎信息', custom),
        const SizedBox(height: 8),
        _InfoRow(
          label: 'VSync 帧率',
          value: '${SchedulerBinding.instance.transientCallbackCount} 帧/秒',
          custom: custom,
        ),
      ],
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    String label,
    CustomTheme custom,
  ) {
    return AppText(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: custom.colors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ── Platform-specific memory helper ────────────────────────────────────────

int _currentRssMb() {
  if (kIsWeb) return 0;

  // macOS / Linux — use ProcessInfo from dart:io
  try {
    final rss = ProcessInfo.currentRss;
    if (rss > 0) return rss ~/ (1024 * 1024);
  } catch (_) {}

  // Linux — read /proc/self/status as fallback
  if (Platform.isLinux) {
    try {
      final file = File('/proc/self/status');
      if (file.existsSync()) {
        for (final line in file.readAsLinesSync()) {
          if (line.startsWith('VmRSS:')) {
            final parts = line.split(RegExp(r'\s+'));
            if (parts.length >= 2) {
              return int.tryParse(parts[1]) ?? 0;
            }
          }
        }
      }
    } catch (_) {}
  }

  return 0;
}

// ── Widgets ────────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final double barValue;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.barValue,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: custom.colors.panel,
        borderRadius: custom.radii.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(icon, size: 14, color: custom.colors.textSecondary),
              const SizedBox(width: 6),
              AppText(
                label,
                variant: AppTextVariant.caption,
                color: custom.colors.textSecondary,
              ),
              const Spacer(),
              AppText(
                value,
                variant: AppTextVariant.subtitle,
                color: color,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              AppText(
                unit,
                variant: AppTextVariant.caption,
                color: custom.colors.textSecondary,
              ),
            ],
          ),
          if (barValue > 0) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(2)),
              child: LinearProgressIndicator(
                value: barValue,
                backgroundColor: custom.colors.hover,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final CustomTheme custom;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.custom,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
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
              color: custom.colors.textPrimary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
