import 'dart:ui' show FramePhase;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// 极轻量的帧统计：每秒打一行，用来判断"卡"是我们自己画不动，还是别的原因。
///
/// 输出格式（logcat 里 grep `UNI-FPS`）：
/// ```
/// UNI-FPS fps=13 build=12.3 raster=28.6 total=40.9 jank=62%
/// ```
/// - `fps`：这一秒真正出帧的数量
/// - `build`：UI 线程构建/布局/录制的平均耗时
/// - `raster`：光栅线程的平均耗时
/// - `jank`：超过 16.7ms 的帧占比
///
/// 与 `UNI-MAP amap=` 那行对照就能看出是"生产端慢"还是"消费端慢"。
class FrameStats {
  FrameStats._();
  static final FrameStats instance = FrameStats._();

  bool _installed = false;
  int _frames = 0, _jank = 0;
  double _build = 0, _raster = 0;
  int? _windowStartMs;
  int? _lastVsyncUs;

  // 帧间隔分布：判断"卡得匀不匀"比平均 fps 更有意义。
  // 33ms 占多数 = 稳定在 30fps；16.7/66 混杂 = 帧率在跳，观感就是顿。
  final List<int> _pacing = [0, 0, 0, 0];

  void install() {
    if (_installed) return;
    _installed = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _frames++;
      _build += t.buildDuration.inMicroseconds / 1000.0;
      _raster += t.rasterDuration.inMicroseconds / 1000.0;
      if (t.totalSpan.inMicroseconds > 16670) _jank++;
      final vsync = t.timestampInMicroseconds(FramePhase.vsyncStart);
      final last = _lastVsyncUs;
      _lastVsyncUs = vsync;
      if (last != null && vsync > last) {
        final gap = (vsync - last) / 1000.0;
        _pacing[gap <= 21
            ? 0
            : gap <= 40
                ? 1
                : gap <= 72
                    ? 2
                    : 3]++;
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final start = _windowStartMs ??= now;
    if (now - start < 1000) return;
    final fps = _frames * 1000 / (now - start);
    final build = _frames == 0 ? 0.0 : _build / _frames;
    final raster = _frames == 0 ? 0.0 : _raster / _frames;
    final jank = _frames == 0 ? 0 : (_jank * 100 / _frames).round();
    debugPrint('UNI-FPS fps=${fps.toStringAsFixed(0)} '
        'build=${build.toStringAsFixed(1)} '
        'raster=${raster.toStringAsFixed(1)} '
        'total=${(build + raster).toStringAsFixed(1)} jank=$jank% '
        'pacing=16:${_pacing[0]} 33:${_pacing[1]} '
        '50:${_pacing[2]} +66:${_pacing[3]}');
    _frames = 0;
    _jank = 0;
    _build = 0;
    _raster = 0;
    for (var i = 0; i < _pacing.length; i++) {
      _pacing[i] = 0;
    }
    _windowStartMs = now;
  }
}
