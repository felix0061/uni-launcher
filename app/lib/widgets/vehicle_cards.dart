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
        final energyFlow = () {
          final vehicle = native['vehicle'];
          final fields = vehicle is Map ? vehicle['fields'] : null;
          final field = fields is Map ? fields['energyFlow'] : null;
          if (field is! Map || field['valid'] != true) return null;
          return '${field['value']}';
        }();
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
              if (!compact) ...[
                EnergyFlowDiagram(state: energyFlow),
                SizedBox(height: Design.px(14)),
              ],
              Container(height: 1, color: s.edge),
              SizedBox(height: Design.px(compact ? 8 : 16)),
              _Footer(
                  '驾驶模式', vehicleStatusLabel(native, 'driveMode', nowMs: now)),
              SizedBox(height: Design.px(4)),
              if (compact)
                _Footer(
                    '能量流', vehicleStatusLabel(native, 'energyFlow', nowMs: now))
              else
                Row(children: [
                  Text('能量流',
                      style:
                          TextStyle(fontSize: Design.px(16), color: s.muted)),
                  SizedBox(width: Design.px(12)),
                  Expanded(
                      child: Text(
                          vehicleStatusLabel(native, 'energyFlow', nowMs: now),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: Design.px(16),
                              color: vehicleStatusLabel(native, 'energyFlow',
                                          nowMs: now) ==
                                      '未连接'
                                  ? s.muted
                                  : s.accent))),
                  Text('外接充电',
                      style:
                          TextStyle(fontSize: Design.px(16), color: s.muted)),
                  SizedBox(width: Design.px(12)),
                  Text('待同步',
                      style:
                          TextStyle(fontSize: Design.px(16), color: s.muted)),
                ]),
              if (compact) ...[
                SizedBox(height: Design.px(4)),
                const _Footer('外接充电', '待同步'),
              ],
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

/// Official-style energy flow: 发动机 — 电池 — 车轮 with per-segment direction.
/// Only officially decoded states light a path; an invalid/unknown state keeps
/// everything dim so a stale read can never look like a live flow.
class EnergyFlowDiagram extends StatelessWidget {
  final String? state;
  const EnergyFlowDiagram({super.key, required this.state});

  // (engine→battery right, battery→wheels right, wheels→battery left)
  (bool, bool, bool, bool engineOn, bool batteryOn, bool wheelsOn) _plan() =>
      switch (state) {
        'ELECTRIC_DRIVE' || 'EAWD' => (false, true, false, false, true, true),
        'ENGINE_ONLY' => (false, true, false, true, false, true),
        'ENGINE_ONLY_AND_CHARGE' || 'STANDSTILL_ENGINE_ON_CHARGE' => (
            true,
            true,
            false,
            true,
            true,
            true
          ),
        'BOOST' => (true, true, false, true, true, true),
        'MAIN_CHARGING' => (true, false, false, false, true, false),
        'ENGINE_OFF_REGEN_BRAKE' ||
        'ENGINE_ON_REGEN_BRAKE' ||
        'ENGINE_ON_REGEN_BRAKE_CHARGE' =>
          (
            false,
            false,
            true,
            state == 'ENGINE_ON_REGEN_BRAKE' ||
                state == 'ENGINE_ON_REGEN_BRAKE_CHARGE',
            true,
            true
          ),
        'STANDSTILL_ENGINE_ON' => (false, false, false, true, false, false),
        _ => (false, false, false, false, false, false),
      };

  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    final (chargeAB, driveBW, regenWB, engineOn, batteryOn, wheelsOn) = _plan();
    Widget node(IconData icon, bool on, String label) =>
        Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: Design.px(40),
              height: Design.px(40),
              decoration: BoxDecoration(
                  color: on
                      ? s.accent.withValues(alpha: .16)
                      : s.muted.withValues(alpha: .10),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: on ? s.accent : s.muted.withValues(alpha: .35),
                      width: 1)),
              child: Icon(icon,
                  size: Design.px(22),
                  color: on ? s.accent : s.muted.withValues(alpha: .7))),
          SizedBox(height: Design.px(4)),
          Text(label,
              style: TextStyle(
                  fontSize: Design.px(13),
                  color: on ? s.text : s.muted.withValues(alpha: .8))),
        ]);
    Widget link({required bool on, required bool left}) => Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              height: Design.px(2),
              margin: EdgeInsets.symmetric(horizontal: Design.px(6)),
              color: on ? s.accent : s.muted.withValues(alpha: .3)),
          SizedBox(height: Design.px(2)),
          Icon(left ? Icons.arrow_back : Icons.arrow_forward,
              size: Design.px(18),
              color: on ? s.accent : s.muted.withValues(alpha: .35)),
        ]));
    return Container(
        padding: EdgeInsets.symmetric(
            horizontal: Design.px(10), vertical: Design.px(8)),
        decoration: BoxDecoration(
            color: s.muted.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(s.radius * .4)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          node(Icons.local_gas_station, engineOn, '发动机'),
          link(on: chargeAB || driveBW, left: false),
          node(Icons.battery_charging_full, batteryOn, '电池'),
          link(on: regenWB, left: true),
          node(Icons.directions_car, wheelsOn, '车轮'),
          if (regenWB)
            Padding(
                padding: EdgeInsets.only(left: Design.px(10)),
                child: Text('能量回收',
                    style:
                        TextStyle(fontSize: Design.px(15), color: s.accent))),
          if (state == 'MAIN_CHARGING')
            Padding(
                padding: EdgeInsets.only(left: Design.px(10)),
                child: Text('充电中',
                    style:
                        TextStyle(fontSize: Design.px(15), color: s.accent))),
        ]));
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
      if (!source.contains('原车') && !source.contains('官方'))
        SizedBox(width: Design.px(12)),
      if (!source.contains('原车') && !source.contains('官方'))
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
