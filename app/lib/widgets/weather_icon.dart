import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../model/weather_condition.dart';

/// Original scalable line art: no bitmap assets or missing font glyphs.
class WeatherIcon extends StatelessWidget {
  final WeatherKind condition;
  final bool night;
  final double size;
  final Color color;
  const WeatherIcon(
      {super.key,
      required this.condition,
      required this.color,
      this.night = false,
      this.size = 96});
  @override
  Widget build(BuildContext context) => Semantics(
      label: '${night ? '夜间' : '日间'}${condition.label}',
      child: SizedBox(
          width: size,
          height: size,
          child:
              CustomPaint(painter: WeatherPainter(condition, night, color))));
}

class WeatherPainter extends CustomPainter {
  final WeatherKind kind;
  final bool night;
  final Color color;
  WeatherPainter(this.kind, this.night, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(double x, double y, double xx, double yy) =>
        canvas.drawLine(Offset(x, y), Offset(xx, yy), pen);
    void cloud() {
      final p = Path()
        ..moveTo(24, 61)
        ..cubicTo(6, 61, 8, 38, 24, 38)
        ..cubicTo(23, 16, 55, 12, 62, 35)
        ..cubicTo(82, 28, 97, 58, 76, 62)
        ..lineTo(24, 62);
      canvas.drawPath(p, pen);
    }

    void sky({bool small = false}) {
      final cx = small ? 69.0 : 50.0,
          cy = small ? 24.0 : 44.0,
          r = small ? 14.0 : 22.0;
      if (night) {
        final p = Path()
          ..moveTo(cx + r * .5, cy - r)
          ..cubicTo(cx - r * 1.5, cy - r * .9, cx - r * 1.4, cy + r * 1.3,
              cx + r * .5, cy + r)
          ..cubicTo(cx - r * .2, cy + r * .2, cx - r * .4, cy - r * .2,
              cx + r * .5, cy - r);
        canvas.drawPath(p, pen);
        line(cx + r, cy - r * .8, cx + r, cy - r * .4);
        line(cx + r - 2, cy - r * .6, cx + r + 2, cy - r * .6);
      } else {
        canvas.drawCircle(Offset(cx, cy), r * .65, pen);
        for (int i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          line(cx + math.cos(a) * r * .95, cy + math.sin(a) * r * .95,
              cx + math.cos(a) * r * 1.25, cy + math.sin(a) * r * 1.25);
        }
      }
    }

    void rain(int count) {
      for (int i = 0; i < count; i++) {
        final x = 24 + i * (50 / (count - 1).clamp(1, 8));
        line(x, 73, x - 5, 84);
        if (count >= 5) line(x + 3, 89, x + 1, 94);
      }
    }

    void snow(int count, {double y = 80}) {
      for (int i = 0; i < count; i++) {
        final x = 24 + i * 50 / (count - 1).clamp(1, 8);
        for (int j = 0; j < 3; j++) {
          final a = j * math.pi / 3;
          line(x - math.cos(a) * 5, y - math.sin(a) * 5, x + math.cos(a) * 5,
              y + math.sin(a) * 5);
        }
      }
    }

    void wind(int rows) {
      for (int i = 0; i < rows; i++) {
        final y = 31.0 + i * 16;
        final p = Path()
          ..moveTo(15, y)
          ..lineTo(65 - i * 8, y)
          ..cubicTo(88, y, 88, y - 22, 72, y - 17);
        canvas.drawPath(p, pen);
      }
      line(25, 87, 54, 87);
    }

    void haze(int rows) {
      for (int i = 0; i < rows; i++) {
        final y = 37.0 + i * 11;
        line(14 + (i % 2) * 9, y, 83 - (i % 3) * 5, y);
      }
    }

    void dots(int rows) {
      for (int r = 0; r < rows; r++)
        for (int i = 0; i < 4; i++)
          canvas.drawCircle(
              Offset(21.0 + i * 18 + (r % 2) * 5, 43.0 + r * 11), 1.5, pen);
    }

    switch (kind) {
      case WeatherKind.clear:
        sky();
        break;
      case WeatherKind.partlyCloudy:
        sky(small: true);
        cloud();
        break;
      case WeatherKind.cloudy:
        canvas.save();
        canvas.translate(4, -6);
        pen.color = color.withValues(alpha: .45);
        cloud();
        canvas.restore();
        pen.color = color;
        cloud();
        break;
      case WeatherKind.overcast:
        cloud();
        line(24, 73, 76, 73);
        break;
      case WeatherKind.shower:
        sky(small: true);
        cloud();
        rain(3);
        break;
      case WeatherKind.thunderstorm:
      case WeatherKind.hail:
        cloud();
        canvas.drawPath(
            Path()
              ..moveTo(52, 68)
              ..lineTo(41, 82)
              ..lineTo(53, 82)
              ..lineTo(45, 96),
            pen);
        if (kind == WeatherKind.hail) {
          for (final x in [25.0, 70.0])
            canvas.drawCircle(Offset(x, 80), 3, pen);
        } else {
          line(25, 73, 21, 83);
          line(75, 73, 71, 83);
        }
        break;
      case WeatherKind.lightRain:
      case WeatherKind.moderateRain:
      case WeatherKind.heavyRain:
      case WeatherKind.rainstorm:
      case WeatherKind.severeRainstorm:
      case WeatherKind.extremeRainstorm:
        cloud();
        rain(2 + kind.index - WeatherKind.lightRain.index);
        break;
      case WeatherKind.freezingRain:
        cloud();
        rain(2);
        snow(1, y: 89);
        line(66, 73, 66, 89);
        line(61, 80, 66, 89);
        line(71, 80, 66, 89);
        break;
      case WeatherKind.sleet:
        cloud();
        line(28, 72, 23, 84);
        snow(2, y: 83);
        break;
      case WeatherKind.snowShower:
        sky(small: true);
        cloud();
        snow(2);
        break;
      case WeatherKind.lightSnow:
      case WeatherKind.moderateSnow:
      case WeatherKind.heavySnow:
      case WeatherKind.blizzard:
        cloud();
        snow(2 + kind.index - WeatherKind.lightSnow.index);
        if (kind == WeatherKind.blizzard) line(18, 95, 80, 95);
        break;
      case WeatherKind.mist:
        sky(small: true);
        haze(3);
        break;
      case WeatherKind.fog:
      case WeatherKind.denseFog:
      case WeatherKind.severeFog:
        cloud();
        for (int i = 0; i < 2 + kind.index - WeatherKind.fog.index; i++)
          line(18 + (i % 2) * 8, 73.0 + i * 7, 82 - (i % 2) * 8, 73.0 + i * 7);
        break;
      case WeatherKind.haze:
      case WeatherKind.moderateHaze:
      case WeatherKind.heavyHaze:
      case WeatherKind.severeHaze:
        pen.color = Color.lerp(color, const Color(0xffd49a47), .5)!;
        haze(3 + kind.index - WeatherKind.haze.index);
        break;
      case WeatherKind.dust:
      case WeatherKind.blowingSand:
      case WeatherKind.sandstorm:
      case WeatherKind.severeSandstorm:
        pen.color = Color.lerp(color, const Color(0xffd49a47), .6)!;
        dots(2 + kind.index - WeatherKind.dust.index);
        if (kind != WeatherKind.dust) {
          line(15, 26, 70, 26);
          line(35, 34, 85, 34);
        }
        break;
      case WeatherKind.wind:
        wind(2);
        break;
      case WeatherKind.gale:
        wind(3);
        break;
      case WeatherKind.tropicalStorm:
        for (int i = 0; i < 3; i++) {
          canvas.save();
          canvas.translate(50, 50);
          canvas.rotate(i * math.pi * 2 / 3);
          canvas.drawPath(
              Path()
                ..moveTo(0, -9)
                ..cubicTo(35, -42, 44, 12, 20, 30)
                ..cubicTo(35, 4, 10, 0, 0, -9),
              pen);
          canvas.restore();
        }
        canvas.drawCircle(const Offset(50, 50), 5, pen);
        break;
      case WeatherKind.hot:
      case WeatherKind.cold:
        final p = Path()
          ..moveTo(43, 61)
          ..lineTo(43, 24)
          ..cubicTo(43, 10, 57, 10, 57, 24)
          ..lineTo(57, 61)
          ..cubicTo(78, 78, 58, 98, 43, 88)
          ..cubicTo(32, 83, 32, 70, 43, 61);
        canvas.drawPath(p, pen);
        line(50, 75, 50, kind == WeatherKind.hot ? 29 : 58);
        if (kind == WeatherKind.hot) {
          line(70, 25, 83, 25);
          line(76, 18, 76, 32);
        } else {
          line(70, 25, 83, 25);
        }
        break;
      case WeatherKind.unknown:
        for (int i = 0; i < 8; i++)
          canvas.drawArc(const Rect.fromLTWH(22, 19, 56, 56), i * math.pi / 4,
              .48, false, pen);
        canvas.drawPath(
            Path()
              ..moveTo(42, 36)
              ..cubicTo(41, 23, 65, 26, 58, 40)
              ..lineTo(50, 48)
              ..lineTo(50, 54),
            pen);
        canvas.drawCircle(const Offset(50, 64), 1, pen);
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(WeatherPainter old) =>
      old.kind != kind || old.night != night || old.color != color;
}
