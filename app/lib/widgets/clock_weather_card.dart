import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../model/card_layout.dart';
import '../model/weather_condition.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';
import 'uni_icon.dart';
import 'weather_icon.dart';

class ClockWeatherLayoutOption {
  final String id, label;
  const ClockWeatherLayoutOption(this.id, this.label);
}

const clockWeatherLayouts = <ClockWeatherLayoutOption>[
  ClockWeatherLayoutOption('combined', '左右组合'),
  ClockWeatherLayoutOption('stacked', '上下组合'),
  ClockWeatherLayoutOption('clock', '纯时钟'),
  ClockWeatherLayoutOption('weather', '纯天气'),
];

String clockWeatherLayoutId(String value) =>
    clockWeatherLayouts.any((option) => option.id == value)
        ? value
        : 'combined';

class ClockWeatherCard extends StatefulWidget {
  final LauncherCard card;
  final Map<String, dynamic> native;
  final bool editing;
  const ClockWeatherCard(
      {super.key,
      required this.card,
      required this.native,
      required this.editing});

  @override
  State<ClockWeatherCard> createState() => _ClockWeatherCardState();
}

class _ClockWeatherCardState extends State<ClockWeatherCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = clockWeatherLayoutId(widget.card.layout);
    return Semantics(
        label:
            '时钟与天气·${clockWeatherLayouts.firstWhere((e) => e.id == id).label}',
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
                          horizontal: Design.px(30), vertical: Design.px(26)),
                      child: switch (id) {
                        'stacked' => _stacked(context),
                        'clock' => _clockOnly(context),
                        'weather' => _weatherOnly(context),
                        _ => _combined(context),
                      })));
        }));
  }

  Widget _combined(BuildContext context) => Row(children: [
        Expanded(flex: 6, child: _ClockFace(title: widget.card.title)),
        Container(
            width: 1,
            margin: EdgeInsets.symmetric(horizontal: Design.px(24)),
            color: SurfaceStyle.of(context).edge),
        Expanded(
            flex: 5,
            child: _WeatherFace(
                weather: WeatherSnapshot.fromNative(widget.native),
                editing: widget.editing,
                centered: true)),
      ]);

  Widget _stacked(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return Column(children: [
      Expanded(child: _ClockFace(title: widget.card.title, horizontal: true)),
      Container(height: 1, color: s.edge),
      Expanded(
          child: _WeatherFace(
              weather: WeatherSnapshot.fromNative(widget.native),
              editing: widget.editing,
              horizontal: true)),
    ]);
  }

  Widget _clockOnly(BuildContext context) =>
      _ClockFace(title: widget.card.title, large: true);

  Widget _weatherOnly(BuildContext context) => _WeatherFace(
      weather: WeatherSnapshot.fromNative(widget.native),
      editing: widget.editing,
      large: true);
}

class _ClockFace extends StatelessWidget {
  final String title;
  final bool horizontal, large;
  const _ClockFace(
      {required this.title, this.horizontal = false, this.large = false});

  @override
  Widget build(BuildContext context) {
    final d = DateTime.now(), s = SurfaceStyle.of(context);
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    final time = Text.rich(
        TextSpan(children: [
          TextSpan(text: d.hour.toString().padLeft(2, '0')),
          TextSpan(text: ':', style: TextStyle(color: s.accent)),
          TextSpan(text: d.minute.toString().padLeft(2, '0')),
        ]),
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
            fontSize: Design.px(large ? 80 : 60),
            height: 1,
            fontWeight: FontWeight.w300,
            letterSpacing: Design.px(3)));
    final date = Text('${d.month} 月 ${d.day} 日 · ${weekdays[d.weekday - 1]}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: Design.px(18), color: s.muted));
    if (horizontal) {
      return Row(children: [
        FittedBox(fit: BoxFit.scaleDown, child: time),
        SizedBox(width: Design.px(28)),
        Expanded(child: date),
      ]);
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: Design.px(19), color: s.muted))),
            UniIcon('clock', size: Design.px(23), color: s.muted),
          ]),
          const Spacer(),
          FittedBox(fit: BoxFit.scaleDown, child: time),
          SizedBox(height: Design.px(10)),
          date,
          const Spacer(),
        ]);
  }
}

class _WeatherFace extends StatelessWidget {
  final WeatherSnapshot weather;
  final bool editing, centered, horizontal, large;
  const _WeatherFace(
      {required this.weather,
      required this.editing,
      this.centered = false,
      this.horizontal = false,
      this.large = false});

  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    final icon = WeatherIcon(
        condition: weather.condition,
        night: weather.night,
        size: Design.px(large ? 104 : 64),
        color: s.accent);
    final temp = Text('${weather.temperature ?? '—'}°',
        maxLines: 1,
        style: TextStyle(
            fontSize: Design.px(large ? 62 : 40),
            height: 1,
            fontWeight: FontWeight.w300));
    final detail = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(weather.city,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: Design.px(19), color: s.muted)),
          SizedBox(height: Design.px(5)),
          temp,
          SizedBox(height: Design.px(4)),
          Text(weather.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: Design.px(19), color: s.muted)),
        ]);
    if (horizontal) {
      return Row(children: [
        icon,
        SizedBox(width: Design.px(20)),
        temp,
        SizedBox(width: Design.px(22)),
        Expanded(
            child: Text('${weather.city} · ${weather.description}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: Design.px(18), color: s.muted))),
      ]);
    }
    if (large) {
      return Row(children: [
        Expanded(child: detail),
        SizedBox(width: Design.px(20)),
        icon,
      ]);
    }
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      icon,
      SizedBox(height: Design.px(editing ? 2 : 8)),
      detail,
    ]);
  }
}
