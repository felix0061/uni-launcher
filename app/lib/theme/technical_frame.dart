import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Static vector framing shared by surfaces and Material controls. The short
/// corner paths follow the same RRect as clipping and hit testing at any radius.
class TechnicalFrameBorder extends OutlinedBorder {
  final double radius, cornerLength;
  final Color cornerColor;
  const TechnicalFrameBorder({
    super.side = BorderSide.none,
    this.radius = 0,
    this.cornerLength = 12,
    required this.cornerColor,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  TechnicalFrameBorder copyWith({BorderSide? side}) => TechnicalFrameBorder(
      side: side ?? this.side,
      radius: radius,
      cornerLength: cornerLength,
      cornerColor: cornerColor);

  @override
  TechnicalFrameBorder scale(double t) => TechnicalFrameBorder(
      side: side.scale(t),
      radius: radius * t,
      cornerLength: cornerLength * t,
      cornerColor: cornerColor);

  RRect _outline(Rect rect) =>
      RRect.fromRectAndRadius(rect, Radius.circular(radius)).scaleRadii();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_outline(rect));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_outline(rect).deflate(side.width));

  /// Each path is a quarter arc and two short tangents, including at radius 0.
  List<Path> cornerPaths(Rect rect) {
    final r = math.min(radius, math.min(rect.width, rect.height) / 2);
    // One shared rule for panels AND controls: a centered arc of at most
    // 60 degrees, capped at the straight corner's single-leg length.
    final base = Path();
    if (r > 0) {
      final sweep = math.min(math.pi / 3, cornerLength / r);
      base.arcTo(Rect.fromLTWH(rect.left, rect.top, r * 2, r * 2),
          math.pi + (math.pi / 2 - sweep) / 2, sweep, true);
    } else {
      final leg = math.min(cornerLength, math.min(rect.width, rect.height) / 2);
      base.moveTo(rect.left, rect.top + leg);
      base.lineTo(rect.left, rect.top);
      base.lineTo(rect.left + leg, rect.top);
    }
    Path mirror(double x, double y) => base.transform((Matrix4.identity()
          ..translateByDouble(rect.center.dx, rect.center.dy, 0, 1)
          ..scaleByDouble(x, y, 1, 1)
          ..translateByDouble(-rect.center.dx, -rect.center.dy, 0, 1))
        .storage);
    return [base, mirror(-1, 1), mirror(1, -1), mirror(-1, -1)];
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (rect.isEmpty) return;
    const cornerWidth = 1.25;
    final inset = math.max(cornerWidth, side.width) / 2;
    final bounds = rect.deflate(inset);
    if (side.style != BorderStyle.none) {
      canvas.drawRRect(_outline(rect).deflate(inset), side.toPaint());
    }
    final paint = Paint()
      ..color = cornerColor
      ..strokeWidth = cornerWidth
      ..style = PaintingStyle.stroke;
    final aligned = TechnicalFrameBorder(
        radius: math.max(0, radius - inset),
        cornerLength: cornerLength,
        cornerColor: cornerColor);
    for (final path in aligned.cornerPaths(bounds)) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is TechnicalFrameBorder &&
      other.side == side &&
      other.radius == radius &&
      other.cornerLength == cornerLength &&
      other.cornerColor == cornerColor;
  @override
  int get hashCode => Object.hash(side, radius, cornerLength, cornerColor);
}
