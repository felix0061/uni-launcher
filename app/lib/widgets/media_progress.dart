import 'dart:async';
import 'package:flutter/material.dart';
import '../model/lyrics.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';

class MediaProgress extends StatefulWidget {
  final Map<String, dynamic> media;
  const MediaProgress({super.key, required this.media});
  @override
  State<MediaProgress> createState() => _MediaProgressState();
}

class _MediaProgressState extends State<MediaProgress> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void didUpdateWidget(MediaProgress old) {
    super.didUpdateWidget(old);
    refresh();
  }

  void refresh() {
    timer?.cancel();
    if (widget.media['playing'] == true &&
        widget.media['positionKnown'] == true)
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  String time(int ms) =>
      '${(ms ~/ 60000).toString().padLeft(2, '0')}:${(ms ~/ 1000 % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context),
        t = MediaTimeline.fromJson(widget.media);
    final p = t.at(DateTime.now().millisecondsSinceEpoch);
    return Column(children: [
      ClipRRect(
          borderRadius: BorderRadius.circular(Design.px(4)),
          child: SizedBox(
              width: double.infinity,
              height: Design.px(4),
              child: Stack(fit: StackFit.expand, children: [
                ColoredBox(color: s.edge),
                if (t.known && t.durationMs > 0)
                  FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (p / t.durationMs).clamp(0, 1),
                      child: ColoredBox(color: s.accent))
              ]))),
      SizedBox(height: Design.px(11)),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (final label in [
          t.known ? time(p) : '--:--',
          t.durationMs > 0 ? time(t.durationMs) : '--:--'
        ])
          Text(label,
              style: TextStyle(
                  fontSize: Design.px(17), height: 1.2, color: s.muted))
      ])
    ]);
  }
}
