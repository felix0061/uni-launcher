import 'dart:async';
import 'package:flutter/material.dart';
import '../model/traffic_light.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';
import 'embedded_navigation.dart';
import 'uni_icon.dart';

/// Shares the outer GlassSurface with all desktop cards. Its second-level timer
/// repaints this card only; it is stopped off-page, in settings and in background.
class TrafficLightCard extends StatefulWidget {
  final TrafficLightSnapshot snapshot;
  final String title, sourceLabel;
  final VoidCallback? onOpenMap;
  final bool editing;
  const TrafficLightCard(
      {super.key,
      required this.snapshot,
      this.title = '红绿灯',
      this.sourceLabel = '高德地图',
      this.onOpenMap,
      this.editing = false});
  @override
  State<TrafficLightCard> createState() => _TrafficLightCardState();
}

class _TrafficLightCardState extends State<TrafficLightCard>
    with WidgetsBindingObserver {
  final clock = Stopwatch();
  Timer? timer;
  int ageAtAnchor = 0;
  int get elapsed => ageAtAnchor + clock.elapsedMilliseconds;
  bool get live =>
      widget.snapshot.available &&
      (widget.snapshot.demo || elapsed < widget.snapshot.ttlMs);
  bool visible = false, foreground = true;

  @override
  void initState() {
    super.initState();
    ageAtAnchor = widget.snapshot.ageMs;
    clock.start();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(TrafficLightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.snapshot, oldWidget.snapshot)) {
      final next = widget.snapshot, previous = oldWidget.snapshot;
      final sameSample = next.sequence == previous.sequence &&
          next.package == previous.package &&
          next.demo == previous.demo;
      ageAtAnchor = sameSample && elapsed > next.ageMs ? elapsed : next.ageMs;
      clock
        ..reset()
        ..start();
    }
    syncTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    visible = TickerMode.valuesOf(context).enabled &&
        EmbeddedContentPolicy.visibleOf(context) &&
        EmbeddedContentPolicy.allowed(context);
    syncTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    syncTimer();
    if (foreground && mounted) setState(() {});
  }

  void syncTimer() {
    timer?.cancel();
    timer = null;
    final data = widget.snapshot;
    if (!visible || !foreground || widget.editing || data.demo || !live) return;
    final left = data.ttlMs - elapsed;
    final nextSecond = 1000 - elapsed % 1000;
    timer = Timer(Duration(milliseconds: left < nextSecond ? left : nextSecond),
        () {
      if (!mounted) return;
      setState(() {});
      syncTimer();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context), data = widget.snapshot;
    return LayoutBuilder(builder: (context, box) {
      final short = box.maxHeight < Design.px(220);
      final padding = Design.px(short ? 20 : 28);
      final content = Padding(
          padding: EdgeInsets.all(padding),
          child: !live
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      _heading(s, small: short),
                      Expanded(
                          child: _waiting(
                              s, data.reason == 'expired' || data.available)),
                    ])
              : _content(s, short, box.maxWidth - padding * 2));
      return Semantics(
          label: '${widget.title}，${data.demo ? '示例数据' : widget.sourceLabel}',
          child: content);
    });
  }

  Widget _heading(SurfaceStyle s, {bool small = false, bool stacked = false}) =>
      Material(
          type: MaterialType.transparency,
          child: InkWell(
              key: const ValueKey('traffic-light-open-map'),
              onTap: widget.editing ? null : widget.onOpenMap,
              borderRadius: BorderRadius.circular(s.controlRadius),
              child: Padding(
                  padding: EdgeInsets.symmetric(vertical: Design.px(4)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          UniIcon('traffic-light',
                              size: Design.px(small ? 23 : 27),
                              color: s.accent),
                          SizedBox(width: Design.px(10)),
                          Expanded(
                              child: Text(widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: Design.px(small ? 22 : 25),
                                      height: 1.2))),
                          if (!stacked) ...[
                            SizedBox(width: Design.px(10)),
                            Expanded(
                                child: Text(_source,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                        fontSize: Design.px(16),
                                        color: s.muted))),
                          ],
                        ]),
                        if (stacked) ...[
                          SizedBox(height: Design.px(10)),
                          Text(_source,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: Design.px(16), color: s.muted)),
                        ],
                      ]))));

  String get _source => widget.snapshot.demo ? '示例数据' : widget.sourceLabel;

  Widget _content(SurfaceStyle s, bool short, double width) {
    final data = widget.snapshot;
    final elapsed = data.demo ? 0 : this.elapsed;
    if (data.lights.length == 1) {
      return Row(children: [
        Expanded(flex: 4, child: _heading(s, small: true, stacked: true)),
        SizedBox(width: Design.px(20)),
        Expanded(
            flex: 6,
            child: _SignalReading(
                signal: data.lights.single, elapsedMs: elapsed, large: !short)),
      ]);
    }
    final columns = data.lights.length.clamp(1, 3);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading(s, small: short),
      SizedBox(height: Design.px(short ? 12 : 24)),
      Expanded(
          child: LayoutBuilder(
              builder: (context, box) => GridView.builder(
                  key: const ValueKey('traffic-light-directions'),
                  padding: EdgeInsets.zero,
                  itemCount: data.lights.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: data.lights.length <= 3
                          ? box.maxHeight
                          : (box.maxHeight / 2)
                              .clamp(Design.px(100), Design.px(150)),
                      crossAxisSpacing: Design.px(10),
                      mainAxisSpacing: Design.px(10)),
                  itemBuilder: (context, i) => _SignalReading(
                      signal: data.lights[i],
                      elapsedMs: elapsed,
                      large: false,
                      stacked: true)))),
      if (!short) ...[
        SizedBox(height: Design.px(18)),
        Container(height: 1, color: s.edge),
        SizedBox(height: Design.px(14)),
        Text('${data.lights.length} 个方向 · 以路口实际信号为准',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: Design.px(15), color: s.muted)),
      ],
    ]);
  }

  Widget _waiting(SurfaceStyle s, bool expired) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
          padding: EdgeInsets.symmetric(vertical: Design.px(16)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            UniIcon(expired ? 'clock' : 'nav',
                size: Design.px(32), color: s.muted),
            SizedBox(width: Design.px(18)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(expired ? '信号暂未更新' : '等待路口信号',
                  style: TextStyle(fontSize: Design.px(22))),
              SizedBox(height: Design.px(10)),
              Text(expired ? '倒计时已隐藏' : '有可用信号时自动显示',
                  style: TextStyle(fontSize: Design.px(16), color: s.muted)),
            ]),
          ])));
}

class _SignalReading extends StatelessWidget {
  final TrafficSignal signal;
  final int elapsedMs;
  final bool large;
  final bool stacked;
  const _SignalReading(
      {required this.signal,
      required this.elapsedMs,
      required this.large,
      this.stacked = false});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    final color = switch (signal.lamp) {
      'red' => Color(s.dark ? 0xFFFF8C7F : 0xFFBA392D),
      'green' => Color(s.dark ? 0xFF71E4B4 : 0xFF087550),
      'amber' => Color(s.dark ? 0xFFFFD17D : 0xFF8C6209),
      _ => s.muted,
    };
    final symbol = switch (signal.direction) {
      'left' => 'signal-left',
      'straight' => 'signal-straight',
      'right' => 'signal-right',
      'uturn' => 'signal-uturn',
      _ => 'traffic-light',
    };
    final seconds = signal.remaining(elapsedMs);
    if (stacked) {
      return Semantics(
          label:
              '${signal.directionLabel}，${signal.lampLabel}，${seconds ?? '未知'}秒',
          child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      UniIcon(symbol, size: Design.px(38), color: color),
                      SizedBox(width: Design.px(10)),
                      Text(seconds?.toString() ?? '—',
                          key: const ValueKey('traffic-light-seconds'),
                          style: TextStyle(
                              fontSize: Design.px(46),
                              height: 1.1,
                              color: color,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ])),
                      SizedBox(width: Design.px(4)),
                      Text('秒',
                          style: TextStyle(
                              fontSize: Design.px(15), color: s.muted)),
                    ]),
                SizedBox(height: Design.px(10)),
                Text('${signal.directionLabel} · ${signal.lampLabel}',
                    style: TextStyle(fontSize: Design.px(17), color: s.muted)),
              ])));
    }
    return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: Design.px(large ? 76 : 64),
              height: Design.px(large ? 76 : 64),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: .12),
                  border: Border.all(color: color.withValues(alpha: .25))),
              child: Center(
                  child: UniIcon(symbol,
                      size: Design.px(large ? 42 : 36), color: color))),
          SizedBox(width: Design.px(large ? 20 : 14)),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(seconds?.toString() ?? '—',
                      key: const ValueKey('traffic-light-seconds'),
                      style: TextStyle(
                          fontSize: Design.px(large ? 74 : 62),
                          height: 1.05,
                          color: color,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                  if (seconds != null) ...[
                    SizedBox(width: Design.px(8)),
                    Text('秒',
                        style:
                            TextStyle(fontSize: Design.px(21), color: s.muted)),
                  ],
                ]),
            SizedBox(height: Design.px(large ? 10 : 6)),
            Row(children: [
              Text(signal.directionLabel,
                  style: TextStyle(fontSize: Design.px(17), color: s.muted)),
              SizedBox(width: Design.px(10)),
              Text(signal.lampLabel,
                  style: TextStyle(fontSize: Design.px(17), color: color)),
            ]),
          ]),
        ]));
  }
}
