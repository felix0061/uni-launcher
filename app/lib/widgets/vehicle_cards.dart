import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../model/vehicle_card_data.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';
import 'uni_icon.dart';

typedef VehicleCardClock = int Function();

/// Content only: the desktop's EditableCard owns the themed glass surface,
/// corners, edit controls and layout. These widgets never send vehicle commands.
class BatteryCard extends StatelessWidget {
  final Map<String, dynamic> native;
  final String title;
  final VehicleCardClock? nowMs;
  const BatteryCard(
      {super.key, required this.native, this.title = '动力电池', this.nowMs});
  @override
  Widget build(BuildContext context) => _VehicleFrame(
      native: native,
      fields: const ['batteryPercent'],
      nowMs: nowMs,
      builder: (context, readings, compact) {
        final reading = readings.single, s = SurfaceStyle.of(context);
        final now = nowMs?.call();
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _VehicleHeading(title, '电量', 'battery', compact),
              Expanded(
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: _Value(reading,
                          field: 'batteryPercent',
                          size: compact ? 56 : 80,
                          unit: '%',
                          accent: true))),
              BatteryLevelBar(value: reading.value),
              SizedBox(height: Design.px(compact ? 10 : 18)),
              _Footer('剩余电量', reading.status,
                  color: reading.available ? s.accent : s.muted),
              SizedBox(height: Design.px(compact ? 8 : 16)),
              Container(height: 1, color: s.edge),
              SizedBox(height: Design.px(compact ? 8 : 16)),
              _Footer(
                  '驾驶模式', vehicleStatusLabel(native, 'driveMode', nowMs: now)),
              SizedBox(height: Design.px(4)),
              _Footer(
                  '能量流', vehicleStatusLabel(native, 'energyFlow', nowMs: now)),
              SizedBox(height: Design.px(4)),
              const _Footer('外接充电', '待同步'),
            ]);
      });
}

/// A continuous track: 95% occupies exactly .95 of the available width.
/// An unavailable value is a neutral track; its main reading remains an em dash.
class BatteryLevelBar extends StatelessWidget {
  final double? value;
  const BatteryLevelBar({super.key, required this.value});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    final percent =
        value != null && value!.isFinite && value! >= 0 && value! <= 100
            ? value
            : null;
    return ExcludeSemantics(
        child: SizedBox(
            height: Design.px(10),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(s.radius * .12),
                child: Stack(fit: StackFit.expand, children: [
                  ColoredBox(
                      key: const ValueKey('battery-track'),
                      color: s.muted.withValues(alpha: .16)),
                  FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: percent == null ? 0 : percent / 100,
                      child: ColoredBox(
                          key: const ValueKey('battery-fill'),
                          color: s.accent)),
                ]))));
  }
}

class AirQualityCard extends StatelessWidget {
  final Map<String, dynamic> native;
  final String title;
  final VehicleCardClock? nowMs;
  const AirQualityCard(
      {super.key, required this.native, this.title = '车内空气', this.nowMs});
  @override
  Widget build(BuildContext context) => _VehicleFrame(
      native: native,
      fields: const ['pm25', 'aqi'],
      nowMs: nowMs,
      builder: (context, readings, compact) {
        final pm = readings[0], aqi = readings[1];
        final s = SurfaceStyle.of(context);
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _VehicleHeading(title, '车内', 'air', compact),
              SizedBox(height: Design.px(compact ? 8 : 18)),
              Text('PM2.5',
                  style: TextStyle(fontSize: Design.px(18), color: s.muted)),
              Expanded(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                    Expanded(
                        child: _Value(pm,
                            field: 'pm25',
                            size: compact ? 54 : 76,
                            unit: 'µg/m³',
                            accent: true)),
                  ])),
              _Footer('PM2.5', pm.status),
              SizedBox(height: Design.px(compact ? 8 : 16)),
              Container(height: 1, color: s.edge),
              SizedBox(height: Design.px(compact ? 8 : 16)),
              Row(children: [
                Text('车内 AQI',
                    style: TextStyle(fontSize: Design.px(18), color: s.muted)),
                SizedBox(width: Design.px(12)),
                Expanded(
                    child: Align(
                        alignment: Alignment.centerRight,
                        child: _Value(aqi,
                            field: 'aqi', size: compact ? 25 : 30))),
                SizedBox(width: Design.px(12)),
                Text(aqi.status,
                    style: TextStyle(fontSize: Design.px(15), color: s.muted)),
              ]),
            ]);
      });
}

class DrivingInfoCard extends StatelessWidget {
  final Map<String, dynamic> native;
  final String title;
  final VehicleCardClock? nowMs;
  const DrivingInfoCard(
      {super.key, required this.native, this.title = '行车信息', this.nowMs});
  @override
  Widget build(BuildContext context) => _VehicleFrame(
      native: native,
      fields: const ['speed', 'odometer', 'range', 'maintenanceMileage'],
      nowMs: nowMs,
      builder: (context, readings, compact) {
        final s = SurfaceStyle.of(context);
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _VehicleHeading(title, '原车', 'car', compact),
              SizedBox(height: Design.px(compact ? 12 : 22)),
              Expanded(
                  child: Column(children: [
                for (int row = 0; row < 2; row++) ...[
                  if (row > 0) ...[
                    SizedBox(height: Design.px(compact ? 10 : 18)),
                    Container(height: 1, color: s.edge),
                    SizedBox(height: Design.px(compact ? 10 : 18)),
                  ],
                  Expanded(
                      child: Row(children: [
                    for (int col = 0; col < 2; col++) ...[
                      if (col > 0) SizedBox(width: Design.px(24)),
                      Expanded(
                          child: _DrivingMetric(
                              reading: readings[row * 2 + col],
                              field: const [
                                'speed',
                                'odometer',
                                'range',
                                'maintenanceMileage'
                              ][row * 2 + col],
                              label: const [
                                '车速',
                                '总里程',
                                '续航',
                                '距保养'
                              ][row * 2 + col],
                              compact: compact)),
                    ]
                  ])),
                ]
              ])),
            ]);
      });
}

class _DrivingMetric extends StatelessWidget {
  final VehicleCardReading reading;
  final String field, label;
  final bool compact;
  const _DrivingMetric(
      {required this.reading,
      required this.field,
      required this.label,
      required this.compact});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              fontSize: Design.px(compact ? 16 : 18), color: s.muted)),
      SizedBox(height: Design.px(compact ? 3 : 7)),
      Expanded(
          child: Align(
              alignment: Alignment.centerLeft,
              child: _Value(reading,
                  field: field,
                  size: compact ? 30 : 40,
                  unit: reading.unit,
                  accent: field == 'speed'))),
      SizedBox(height: Design.px(3)),
      Text(reading.status,
          key: ValueKey('vehicle-status-$field'),
          style: TextStyle(
              fontSize: Design.px(compact ? 13 : 15), color: s.muted)),
    ]);
  }
}

class _Value extends StatelessWidget {
  final VehicleCardReading reading;
  final String field, unit;
  final double size;
  final bool accent;
  const _Value(this.reading,
      {required this.field,
      required this.size,
      this.unit = '',
      this.accent = false});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return Semantics(
        label:
            '${_fieldLabels[field] ?? field} ${reading.display}${reading.available ? ' $unit' : ''}，${reading.status}',
        child: ExcludeSemantics(
            child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(reading.display,
                          key: ValueKey('vehicle-value-$field'),
                          style: TextStyle(
                              fontSize: Design.px(size),
                              height: 1,
                              fontWeight: FontWeight.w300,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                              color: reading.available
                                  ? (accent ? s.accent : s.text)
                                  : s.muted)),
                      // Fixed canonical labels remain useful in missing-data states;
                      // unconfirmed driving units are deliberately absent.
                      if (unit.isNotEmpty) ...[
                        SizedBox(width: Design.px(8)),
                        Text(unit,
                            style: TextStyle(
                                fontSize: Design.px(size >= 50 ? 22 : 16),
                                color: s.muted,
                                height: 1)),
                      ],
                    ]))));
  }
}

const _fieldLabels = {
  'batteryPercent': '剩余电量',
  'pm25': '车内 PM2.5',
  'aqi': '车内 AQI',
  'speed': '车速',
  'odometer': '总里程',
  'range': '续航',
  'maintenanceMileage': '距保养',
};

class _VehicleHeading extends StatelessWidget {
  final String title, source, icon;
  final bool compact;
  const _VehicleHeading(this.title, this.source, this.icon, this.compact);
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return Row(children: [
      UniIcon(icon, color: s.accent, size: Design.px(compact ? 23 : 27)),
      SizedBox(width: Design.px(10)),
      Expanded(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: Design.px(compact ? 21 : 25), height: 1.2))),
      SizedBox(width: Design.px(12)),
      Text(source, style: TextStyle(fontSize: Design.px(16), color: s.muted)),
    ]);
  }
}

class _Footer extends StatelessWidget {
  final String label, status;
  final Color? color;
  const _Footer(this.label, this.status, {this.color});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return Row(children: [
      Expanded(
          child: Text(label,
              style: TextStyle(fontSize: Design.px(16), color: s.muted))),
      Expanded(
          child: Text(status,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(fontSize: Design.px(16), color: color ?? s.muted))),
    ]);
  }
}

typedef _VehicleBuilder = Widget Function(
    BuildContext, List<VehicleCardReading>, bool);

/// Re-evaluate at each field's deadline even if the native stream goes quiet.
class _VehicleFrame extends StatefulWidget {
  final Map<String, dynamic> native;
  final List<String> fields;
  final VehicleCardClock? nowMs;
  final _VehicleBuilder builder;
  const _VehicleFrame(
      {required this.native,
      required this.fields,
      required this.builder,
      this.nowMs});
  @override
  State<_VehicleFrame> createState() => _VehicleFrameState();
}

class _VehicleFrameState extends State<_VehicleFrame> {
  Timer? timer;
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.nowMs?.call() ?? DateTime.now().millisecondsSinceEpoch;
    final readings = [
      for (final key in widget.fields)
        VehicleCardReading.fromNative(widget.native, key, nowMs: now)
    ];
    timer?.cancel();
    final vehicle = widget.native['vehicle'];
    final fields = vehicle is Map ? vehicle['fields'] : null;
    final statusDeadlines = fields is Map
        ? [
            for (final key in ['driveMode', 'energyFlow'])
              if (fields[key] is Map &&
                  fields[key]['valid'] == true &&
                  fields[key]['updatedAtMs'] is num &&
                  (fields[key]['updatedAtMs'] as num).isFinite)
                (fields[key]['updatedAtMs'] as num).toInt() + 5001 - now,
          ]
        : <int>[];
    final deadlines = [
      ...readings
          .where((r) => r.available)
          .map((r) => r.updatedAtMs + 5001 - now),
      ...statusDeadlines
    ].where((ms) => ms > 0);
    if (deadlines.isNotEmpty) {
      timer = Timer(Duration(milliseconds: deadlines.reduce(math.min)), () {
        if (mounted) setState(() {});
      });
    }
    return LayoutBuilder(builder: (context, box) {
      final compact =
          box.maxHeight < Design.px(300) || box.maxWidth < Design.px(370);
      final textScale =
          math.max(1.0, MediaQuery.textScalerOf(context).scale(20) / 20);
      final width = math.max(box.maxWidth, Design.px(300) * textScale);
      final height =
          math.max(box.maxHeight, Design.px(compact ? 205 : 300) * textScale);
      final content = Padding(
          padding: EdgeInsets.symmetric(
              horizontal: Design.px(compact ? 22 : 30),
              vertical: Design.px(compact ? 18 : 28)),
          child: widget.builder(context, readings, compact));
      if (width == box.maxWidth && height == box.maxHeight) return content;
      return FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(width: width, height: height, child: content));
    });
  }
}
