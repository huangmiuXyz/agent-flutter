import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:agent/widgets/text/app_text.dart';

/// 一次异常记录的帧数据
class _FrameSample {
  final DateTime time;
  final double buildMs;
  final double rasterMs;

  _FrameSample({
    required this.time,
    required this.buildMs,
    required this.rasterMs,
  });

  String get formatted {
    final t =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
    return '[$t] build=${buildMs.toStringAsFixed(1)}ms raster=${rasterMs.toStringAsFixed(1)}ms';
  }
}

/// 环形缓冲区，记录最近 N 秒的帧数据
class _FrameHistory {
  final _samples = <_FrameSample>[];

  void add(double buildMs, double rasterMs) {
    _samples.add(
      _FrameSample(time: DateTime.now(), buildMs: buildMs, rasterMs: rasterMs),
    );
    final cutoff = DateTime.now().subtract(const Duration(seconds: 30));
    while (_samples.isNotEmpty && _samples.first.time.isBefore(cutoff)) {
      _samples.removeAt(0);
    }
  }

  List<_FrameSample> get all => List.unmodifiable(_samples);
  int get count => _samples.length;
  bool get hasAnomaly => _samples.any((s) => s.buildMs > 16);
}

/// 悬浮按钮 + 展开面板的性能监视器，自动记录掉帧数据。
class FpsMonitor extends HookWidget {
  const FpsMonitor({super.key});

  @override
  Widget build(BuildContext context) {
    final open = useState(false);
    final history = useMemoized(() => _FrameHistory());
    final fps = useState(0.0);
    final buildMs = useState(0.0);
    final rasterMs = useState(0.0);

    useEffect(() {
      var frameCount = 0;
      var buildUs = 0;
      var rasterUs = 0;
      var timingCount = 0;

      void onTimings(List<FrameTiming> timings) {
        frameCount += timings.length;
        for (final t in timings) {
          buildUs += t.buildDuration.inMicroseconds;
          rasterUs += t.rasterDuration.inMicroseconds;
        }
        timingCount += timings.length;
      }

      SchedulerBinding.instance.addTimingsCallback(onTimings);
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        fps.value = frameCount.toDouble();
        frameCount = 0;
        final avgBuild = timingCount > 0 ? buildUs / timingCount / 1000.0 : 0.0;
        final avgRaster = timingCount > 0
            ? rasterUs / timingCount / 1000.0
            : 0.0;
        buildMs.value = avgBuild;
        rasterMs.value = avgRaster;
        history.add(avgBuild, avgRaster);
        buildUs = 0;
        rasterUs = 0;
        timingCount = 0;
      });

      return () {
        SchedulerBinding.instance.removeTimingsCallback(onTimings);
        timer.cancel();
      };
    }, [history]);

    final color = fps.value >= 55
        ? const Color(0xFF4ADE80)
        : fps.value >= 30
        ? const Color(0xFFFBBF24)
        : const Color(0xFFF87171);

    return Stack(
      children: [
        // FAB — FPS 实时显示
        Positioned(
          right: 16,
          bottom: 72,
          child: FloatingActionButton(
            mini: true,
            onPressed: () => open.value = !open.value,
            backgroundColor: color,
            foregroundColor: Colors.black87,
            child: AppText(
              fps.value.toStringAsFixed(0),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),

        // 有异常时显示红点标记
        if (history.hasAnomaly && !open.value)
          Positioned(
            right: 12,
            bottom: 108,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF87171),
              ),
            ),
          ),

        // 背板
        if (open.value)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => open.value = false,
              child: Container(color: Colors.black26),
            ),
          ),

        // 性能面板
        if (open.value)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 320,
            child: Material(
              elevation: 16,
              color: const Color(0xFF1E1E1E),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                      child: Row(
                        children: [
                          const AppText(
                            '性能监视',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const Spacer(),
                          // 复制日志
                          TextButton.icon(
                            onPressed: () => _copyAll(history),
                            icon: const Icon(
                              LucideIcons.copy,
                              size: 14,
                              color: Colors.white38,
                            ),
                            label: const AppText(
                              '复制日志',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white38,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              LucideIcons.x,
                              size: 18,
                              color: Colors.white54,
                            ),
                            onPressed: () => open.value = false,
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 8),

                    // 实时数值
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _stat('FPS', fps.value.toStringAsFixed(0), color),
                          const SizedBox(width: 24),
                          _stat(
                            'Build',
                            '${buildMs.value.toStringAsFixed(1)}ms',
                            buildMs.value > 16
                                ? const Color(0xFFF87171)
                                : Colors.white70,
                          ),
                          const SizedBox(width: 24),
                          _stat(
                            'Raster',
                            '${rasterMs.value.toStringAsFixed(1)}ms',
                            rasterMs.value > 16
                                ? const Color(0xFFF87171)
                                : Colors.white70,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 异常记录
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AppText(
                        history.hasAnomaly ? '掉帧记录' : '暂无异常',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: history.hasAnomaly
                              ? const Color(0xFFF87171)
                              : Colors.white38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // 异常列表
                    Expanded(
                      child: history.hasAnomaly
                          ? ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              itemCount: history.count,
                              itemBuilder: (context, index) {
                                final s = history.all[index];
                                final isBad = s.buildMs > 16;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: AppText(
                                    s.formatted,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isBad
                                          ? const Color(0xFFF87171)
                                          : Colors.white54,
                                    ),
                                  ),
                                );
                              },
                            )
                          : const Center(
                              child: AppText(
                                '性能正常',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white30,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white38),
        ),
        const SizedBox(height: 2),
        AppText(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  void _copyAll(_FrameHistory h) {
    if (h.all.isEmpty) return;
    final text = h.all.map((s) => s.formatted).join('\n');
    Clipboard.setData(ClipboardData(text: text));
  }
}
