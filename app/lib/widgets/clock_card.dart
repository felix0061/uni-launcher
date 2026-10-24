import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';
import 'uni_icon.dart';

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
    // This card explicitly represents system time. OEM calendar dates are handled
    // separately and never fall back to the system clock.
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return Semantics(
        label: '系统时间',
        child: LayoutBuilder(builder: (context, box) {
          final width = math.max(box.maxWidth, Design.px(340));
          final height = math.max(box.maxHeight, Design.px(230));
          return FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                  width: width,
                  height: height,
                  child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: Design.px(30), vertical: Design.px(28)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text(widget.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: Design.px(23),
                                          height: 1.2,
                                          color: s.muted))),
                              UniIcon('clock',
                                  size: Design.px(32), color: s.muted)
                            ]),
                            SizedBox(height: Design.px(16)),
                            FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text.rich(
                                    TextSpan(children: [
                                      TextSpan(
                                          text: d.hour
                                              .toString()
                                              .padLeft(2, '0')),
                                      TextSpan(
                                          text: ':',
                                          style: TextStyle(color: s.accent)),
                                      TextSpan(
                                          text: d.minute
                                              .toString()
                                              .padLeft(2, '0')),
                                    ]),
                                    style: TextStyle(
                                        fontSize: Design.px(78),
                                        height: 1,
                                        fontWeight: FontWeight.w300,
                                        letterSpacing: Design.px(4)),
                                    maxLines: 1,
                                    softWrap: false)),
                            SizedBox(height: Design.px(4)),
                            Text(
                                '${d.month} 月 ${d.day} 日 · ${weekdays[d.weekday - 1]}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: Design.px(20),
                                    height: 1.2,
                                    color: s.muted)),
                          ]))));
        }));
  }
}
