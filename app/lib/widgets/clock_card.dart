import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/launcher_theme.dart';
import 'glass_surface.dart';

class ClockCard extends StatefulWidget {
  final String title;
  const ClockCard({super.key, required this.title});
  @override
  State<ClockCard> createState() => _ClockCardState();
}

class _ClockCardState extends State<ClockCard> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = DateTime.now(), s = SurfaceStyle.of(context);
    return Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CardHeading(widget.title, '系统时间', Icons.schedule),
          Expanded(
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    fontSize: 56, fontWeight: FontWeight.w300)),
                            Text('${d.year} 年 ${d.month} 月 ${d.day} 日',
                                style: TextStyle(fontSize: 18, color: s.muted)),
                          ])))),
        ]));
  }
}
