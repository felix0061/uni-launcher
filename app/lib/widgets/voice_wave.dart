import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/launcher_theme.dart';

/// 语音激活状态波纹：聆听中扩散环 / 识别中脉冲 / 回复中声波 / 待机微光。
/// 单个 AnimationController 驱动 CustomPaint，避免多层动画在车机上的开销。
class VoiceWave extends StatefulWidget {
  final String state;
  final double size;
  const VoiceWave({super.key, required this.state, this.size = 120});

  @override
  State<VoiceWave> createState() => _VoiceWaveState();
}

class _VoiceWaveState extends State<VoiceWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(VoiceWave old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _sync();
  }

  void _sync() {
    _c.stop();
    _c.duration = switch (widget.state) {
      'thinking' => const Duration(milliseconds: 850),
      'speaking' => const Duration(milliseconds: 720),
      'listening' => const Duration(milliseconds: 2100),
      _ => const Duration(milliseconds: 3000),
    };
    _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: VoiceRipplePainter(
                state: widget.state,
                t: _c.value,
                accent: s.accent,
                muted: s.muted)));
  }
}

class VoiceRipplePainter extends CustomPainter {
  final String state;
  final double t;
  final Color accent, muted;
  VoiceRipplePainter(
      {required this.state,
      required this.t,
      required this.accent,
      required this.muted});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    switch (state) {
      case 'listening':
        _rings(canvas, c, r, 3, t);
        _core(canvas, c, r);
      case 'thinking':
        _pulse(canvas, c, r, t);
      case 'speaking':
        _bars(canvas, c, r, t);
        _core(canvas, c, r);
      default:
        _dormant(canvas, c, r);
    }
  }

  void _core(Canvas canvas, Offset c, double r) {
    final glow = Paint()
      ..color = accent.withValues(alpha: .20)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, r * .30, glow);
    final rim = Paint()
      ..color = accent.withValues(alpha: .42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .045;
    canvas.drawCircle(c, r * .22, rim);
    final dot = Paint()
      ..color = accent.withValues(alpha: .95)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, r * .12, dot);
  }

  void _rings(Canvas canvas, Offset c, double r, int count, double t) {
    for (int i = 0; i < count; i++) {
      final phase = (t + i / count) % 1.0;
      final eased = 1 - math.pow(1 - phase, 3).toDouble();
      final radius = r * (0.30 + eased * 0.70);
      final paint = Paint()
        ..color = accent.withValues(alpha: (1 - phase).clamp(0.0, 1.0) * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05 * (1 - phase * 0.55)
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(c, radius, paint);
    }
  }

  void _pulse(Canvas canvas, Offset c, double r, double t) {
    final breathe = 0.5 + 0.5 * math.sin(2 * math.pi * t);
    final glow = Paint()
      ..color = accent.withValues(alpha: .12 + breathe * .16)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, r * (0.24 + breathe * 0.10), glow);
    final dot = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, r * (0.10 + breathe * 0.03), dot);
    for (int i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final angle = phase * 2 * math.pi;
      final pos = c + Offset(math.cos(angle), math.sin(angle)) * (r * 0.42);
      final p = Paint()
        ..color = accent.withValues(alpha: (1 - phase) * .9)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, r * .045 * (1 - phase * .5), p);
    }
  }

  void _bars(Canvas canvas, Offset c, double r, double t) {
    const count = 30;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .05
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < count; i++) {
      final angle = i * 2 * math.pi / count;
      final amp = 0.5 + 0.5 * math.sin(2 * math.pi * t * 1.5 + i * 0.55);
      final dir = Offset(math.cos(angle), math.sin(angle));
      final base = r * 0.34;
      final len = r * (0.05 + amp * 0.16);
      paint.color = accent.withValues(alpha: .30 + amp * .60);
      canvas.drawLine(c + dir * base, c + dir * (base + len), paint);
    }
  }

  void _dormant(Canvas canvas, Offset c, double r) {
    final breathe = 0.5 + 0.5 * math.sin(2 * math.pi * t * 0.5);
    final glow = Paint()
      ..color = muted.withValues(alpha: .08 + breathe * .05)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, r * .26, glow);
    final dot = Paint()
      ..color = muted.withValues(alpha: .45)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, r * .10, dot);
  }

  @override
  bool shouldRepaint(VoiceRipplePainter old) =>
      old.t != t ||
      old.state != state ||
      old.accent != accent ||
      old.muted != muted;
}
