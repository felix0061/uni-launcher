import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/vehicle_data.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';

/// Optional opening-state contract used by vehicle visuals.
///
/// The current IP753 adapter does not publish these fields yet. A future native
/// reader can add any subset to `vehicle.fields` without changing the widgets:
/// doorFrontLeft, doorFrontRight, doorRearLeft, doorRearRight, tailgateOpen and
/// hoodOpen. Each field uses the standard {valid, value, updatedAtMs} envelope.
@immutable
class VehicleDoorSnapshot {
  final bool? frontLeft;
  final bool? frontRight;
  final bool? rearLeft;
  final bool? rearRight;
  final bool? tailgate;
  final bool? hood;

  const VehicleDoorSnapshot({
    this.frontLeft,
    this.frontRight,
    this.rearLeft,
    this.rearRight,
    this.tailgate,
    this.hood,
  });

  factory VehicleDoorSnapshot.fromNative(Map<String, dynamic> native,
      {int? nowMs}) {
    final vehicle = native['vehicle'];
    final fields = vehicle is Map ? vehicle['fields'] : null;
    bool? read(String key) {
      if (vehicle is! Map || vehicle['connected'] != true || fields is! Map) {
        return null;
      }
      final field = fields[key];
      if (field is! Map || field['valid'] != true) return null;
      final updated = field['updatedAtMs'];
      final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
      if (updated is! num) return null;
      final age = now - updated.toInt();
      if (age < -1000 || age > 5000) return null;
      final value = field['value'];
      if (value is bool) return value;
      if (value is num && (value == 0 || value == 1)) return value == 1;
      final normalized = '$value'.trim().toUpperCase();
      if (const {'OPEN', 'OPENED', 'ON', 'TRUE'}.contains(normalized)) {
        return true;
      }
      if (const {'CLOSED', 'CLOSE', 'OFF', 'FALSE'}.contains(normalized)) {
        return false;
      }
      return null;
    }

    return VehicleDoorSnapshot(
      frontLeft: read('doorFrontLeft'),
      frontRight: read('doorFrontRight'),
      rearLeft: read('doorRearLeft'),
      rearRight: read('doorRearRight'),
      tailgate: read('tailgateOpen'),
      hood: read('hoodOpen'),
    );
  }

  bool get hasData =>
      frontLeft != null ||
      frontRight != null ||
      rearLeft != null ||
      rearRight != null ||
      tailgate != null ||
      hood != null;

  bool get anyOpen =>
      frontLeft == true ||
      frontRight == true ||
      rearLeft == true ||
      rearRight == true ||
      tailgate == true ||
      hood == true;

  String get statusLabel {
    if (!hasData) return '车门状态未接入';
    final open = <String>[
      if (frontLeft == true) '左前门',
      if (frontRight == true) '右前门',
      if (rearLeft == true) '左后门',
      if (rearRight == true) '右后门',
      if (tailgate == true) '尾门',
      if (hood == true) '机舱盖',
    ];
    return open.isEmpty ? '车门均已关闭' : '${open.join('、')}开启';
  }

  @override
  bool operator ==(Object other) =>
      other is VehicleDoorSnapshot &&
      other.frontLeft == frontLeft &&
      other.frontRight == frontRight &&
      other.rearLeft == rearLeft &&
      other.rearRight == rearRight &&
      other.tailgate == tailgate &&
      other.hood == hood;

  @override
  int get hashCode =>
      Object.hash(frontLeft, frontRight, rearLeft, rearRight, tailgate, hood);
}

/// Horizontal TPMS visual traced from the supplied Lynk & Co 05 top view.
/// It deliberately uses a lightweight vector painter so theme colors,
/// dark/light modes and optional opening states remain live without maintaining
/// separate raster assets.
class TireDiagram extends StatelessWidget {
  static const _vehicleAspect = 1826 / 833;
  final Map<String, dynamic> native;
  final int? nowMs;
  const TireDiagram({super.key, this.native = const {}, this.nowMs});

  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    final doors = VehicleDoorSnapshot.fromNative(native, nowMs: nowMs);
    final tires = <_TirePosition>[
      _TirePosition('左后', 'pressureRearLeft', Alignment.topLeft),
      _TirePosition('左前', 'pressureFrontLeft', Alignment.topRight),
      _TirePosition('右后', 'pressureRearRight', Alignment.bottomLeft),
      _TirePosition('右前', 'pressureFrontRight', Alignment.bottomRight),
    ];
    return LayoutBuilder(builder: (context, box) {
      final compact =
          box.maxHeight < Design.px(250) || box.maxWidth < Design.px(430);
      final nodeWidth = math.min(
          Design.px(compact ? 96 : 124), box.maxWidth * (compact ? .28 : .25));
      final carInset = math.max(nodeWidth * .72, Design.px(62));
      final carWidth = math.max(0.0, box.maxWidth - carInset * 2);
      final carHeight = math.min(
          box.maxHeight * (compact ? .58 : .62), carWidth / _vehicleAspect);
      Widget node(_TirePosition tire) {
        final reading = VehicleField.fromNative(native, tire.field,
            nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch);
        return _PressureNode(
            label: tire.label,
            value: reading.display(decimals: 2),
            available: reading.valid,
            compact: compact,
            width: nodeWidth);
      }

      return Semantics(
          label: '领克05胎压示意，${doors.statusLabel}',
          child: Stack(fit: StackFit.expand, children: [
            Positioned(
                left: carInset,
                right: carInset,
                top: (box.maxHeight - carHeight) / 2,
                height: carHeight,
                child: RepaintBoundary(
                    child: _Lynk05TopView(
                        key: const ValueKey('lynk-05-horizontal-vehicle'),
                        style: s,
                        doors: doors))),
            for (final tire in tires)
              Align(
                  alignment: tire.alignment,
                  child: Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: Design.px(compact ? 2 : 7)),
                      child: node(tire))),
            if (doors.anyOpen)
              Align(
                  alignment: Alignment.center,
                  child: Container(
                      key: const ValueKey('vehicle-opening-alert'),
                      padding: EdgeInsets.symmetric(
                          horizontal: Design.px(10), vertical: Design.px(5)),
                      decoration: BoxDecoration(
                          color: const Color(0xffffb45c).withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(Design.px(20)),
                          border: Border.all(
                              color: const Color(0xffffb45c)
                                  .withValues(alpha: .65))),
                      child: Text('车门开启',
                          style: TextStyle(
                              fontSize: Design.px(compact ? 12 : 14),
                              color: const Color(0xffffb45c))))),
          ]));
    });
  }
}

class _TirePosition {
  final String label, field;
  final Alignment alignment;
  const _TirePosition(this.label, this.field, this.alignment);
}

class _PressureNode extends StatelessWidget {
  final String label, value;
  final bool available, compact;
  final double width;
  const _PressureNode(
      {required this.label,
      required this.value,
      required this.available,
      required this.compact,
      required this.width});

  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    final color = available ? s.accent : s.muted;
    return SizedBox(
        width: width,
        child: DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      color.withValues(alpha: .13),
                      color.withValues(alpha: .025)
                    ]),
                borderRadius: BorderRadius.circular(Design.px(10)),
                border: Border.all(color: color.withValues(alpha: .22))),
            child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: Design.px(compact ? 8 : 11),
                    vertical: Design.px(compact ? 5 : 8)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Container(
                        width: Design.px(4),
                        height: Design.px(4),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: color)),
                    SizedBox(width: Design.px(6)),
                    Text(label,
                        style: TextStyle(
                            fontSize: Design.px(compact ? 12 : 14),
                            height: 1,
                            color: s.muted)),
                  ]),
                  SizedBox(height: Design.px(compact ? 3 : 6)),
                  FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(value,
                                style: TextStyle(
                                    fontSize: Design.px(compact ? 24 : 31),
                                    height: 1,
                                    fontWeight: FontWeight.w300,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                    color: available ? s.text : s.muted)),
                            SizedBox(width: Design.px(6)),
                            Text('bar',
                                style: TextStyle(
                                    fontSize: Design.px(compact ? 11 : 13),
                                    height: 1,
                                    color: s.muted)),
                          ])),
                ]))));
  }
}

class _Lynk05TopView extends StatelessWidget {
  final SurfaceStyle style;
  final VehicleDoorSnapshot doors;
  const _Lynk05TopView({
    super.key,
    required this.style,
    required this.doors,
  });

  @override
  Widget build(BuildContext context) {
    Widget trace(double opacity) => Transform.rotate(
          angle: math.pi,
          child: Image.asset(
            'assets/art/lynk-05-top-line.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
            gaplessPlayback: true,
            color: style.accent.withValues(alpha: opacity),
            colorBlendMode: BlendMode.srcIn,
            semanticLabel: '领克05原图等比俯视线稿，车头向右',
          ),
        );
    return Stack(fit: StackFit.expand, children: [
      trace(style.dark ? .18 : .12),
      trace(style.dark ? .82 : .72),
      if (doors.anyOpen)
        CustomPaint(painter: _VehicleOpeningPainter(doors: doors)),
    ]);
  }
}

/// Opening-state marks intentionally remain a separate overlay. With unknown or
/// closed values the supplied top-view trace is shown without additional lines.
class _VehicleOpeningPainter extends CustomPainter {
  final VehicleDoorSnapshot doors;
  const _VehicleOpeningPainter({required this.doors});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !doors.anyOpen) return;
    final w = size.width, h = size.height;
    final warning = Paint()
      ..color = const Color(0xffffb45c)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = Design.px(2.4);

    void door(bool? open, Offset hinge, Offset openEnd) {
      if (open != true) return;
      canvas.drawLine(hinge, openEnd, warning);
      canvas.drawCircle(
          openEnd, Design.px(2.6), Paint()..color = const Color(0xffffb45c));
    }

    // The displayed trace points right. Vehicle-left doors are on the top edge.
    door(doors.frontLeft, Offset(w * .58, h * .16), Offset(w * .62, 0));
    door(doors.rearLeft, Offset(w * .36, h * .16), Offset(w * .39, 0));
    door(doors.frontRight, Offset(w * .58, h * .84), Offset(w * .62, h));
    door(doors.rearRight, Offset(w * .36, h * .84), Offset(w * .39, h));
    if (doors.tailgate == true) {
      canvas.drawLine(Offset(w * .07, h * .30), Offset(0, h * .18), warning);
      canvas.drawLine(Offset(w * .07, h * .70), Offset(0, h * .82), warning);
    }
    if (doors.hood == true) {
      canvas.drawLine(
          Offset(w * .76, h * .26), Offset(w * .92, h * .11), warning);
      canvas.drawLine(
          Offset(w * .76, h * .74), Offset(w * .92, h * .89), warning);
    }
  }

  @override
  bool shouldRepaint(covariant _VehicleOpeningPainter oldDelegate) =>
      oldDelegate.doors != doors;
}
