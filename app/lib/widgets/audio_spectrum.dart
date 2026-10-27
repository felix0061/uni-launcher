import 'package:flutter/material.dart';
import '../platform/audio_spectrum.dart';
import '../theme/launcher_theme.dart';
import '../theme/design_tokens.dart';

/// Only the tiny painted region repaints when a native FFT frame arrives.
/// There is no ticker, per-frame setState, bitmap, shader animation or blur.
class AudioSpectrum extends StatefulWidget {
  final bool playing;
  final double height;
  final AudioSpectrumService? service;
  const AudioSpectrum(
      {super.key, required this.playing, this.height = 42, this.service});
  @override
  State<AudioSpectrum> createState() => _AudioSpectrumState();
}

class _AudioSpectrumState extends State<AudioSpectrum>
    with WidgetsBindingObserver {
  late AudioSpectrumService service;
  bool visible = true, resumed = true, scheduled = false;
  String presentation = '';
  @override
  void initState() {
    super.initState();
    service = widget.service ?? AudioSpectrumService.shared;
    presentation = service.status;
    resumed = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    service.addListener(statusChanged);
    WidgetsBinding.instance.addObserver(this);
    service.refreshStatus();
  }

  void statusChanged() {
    if (!mounted || presentation == service.status) return;
    setState(() => presentation = service.status);
  }

  void scheduleDemand() {
    if (scheduled) return;
    scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduled = false;
      if (mounted)
        service.setDemand(this, visible && resumed && widget.playing);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    visible = TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    scheduleDemand();
  }

  @override
  void didUpdateWidget(AudioSpectrum old) {
    super.didUpdateWidget(old);
    if (old.service != widget.service) {
      service.removeListener(statusChanged);
      service.setDemand(this, false);
      service = widget.service ?? AudioSpectrumService.shared;
      presentation = service.status;
      service.addListener(statusChanged);
      service.refreshStatus();
    }
    scheduleDemand();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    resumed = state == AppLifecycleState.resumed;
    service.setDemand(this, visible && resumed && widget.playing);
    if (resumed) service.refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    service.removeListener(statusChanged);
    service.setDemand(this, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return SizedBox(
        height: Design.px(widget.height),
        child: Semantics(
            label: '音频频谱，设备播放输出混音',
            child: RepaintBoundary(
                child: Stack(fit: StackFit.expand, children: [
              CustomPaint(
                  key: const ValueKey('audio-spectrum-paint'),
                  painter: AudioSpectrumPainter(service, s.accent, s.edge)),
              if (!service.granted && presentation == 'permission-required')
                Center(
                    child: TextButton.icon(
                        key: const ValueKey('enable-audio-spectrum'),
                        onPressed: service.requestPermission,
                        style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: EdgeInsets.symmetric(
                                horizontal: Design.px(10),
                                vertical: Design.px(3))),
                        icon: Icon(Icons.graphic_eq, size: Design.px(20)),
                        label: Text('启用频谱',
                            style: TextStyle(fontSize: Design.px(16))))),
            ]))));
  }
}

class AudioSpectrumPainter extends CustomPainter {
  final AudioSpectrumService service;
  final Color accent, edge;
  AudioSpectrumPainter(this.service, this.accent, this.edge)
      : super(repaint: service);
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final track = Paint()..color = edge.withValues(alpha: .45);
    final paint = Paint()
      ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [accent, accent.withValues(alpha: .28)])
          .createShader(Offset.zero & size);
    const bands = 24;
    final step = size.width / bands, width = (step * .48).clamp(1.0, 6.0);
    for (var i = 0; i < bands; i++) {
      final x = (i + .5) * step;
      final value = service.available && i < service.levels.length
          ? service.levels[i]
          : 0.0;
      final h = (value * (size.height - 3)).clamp(1.0, size.height);
      final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(x, size.height / 2), width: width, height: h),
          const Radius.circular(1));
      canvas.drawRRect(rect, value > .015 ? paint : track);
    }
  }

  @override
  bool shouldRepaint(AudioSpectrumPainter old) =>
      old.service != service || old.accent != accent || old.edge != edge;
}
