import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_launcher/widgets/spectrum_painter.dart';

void main() {
  test('contour stays in bounds for peaks, silence and malformed bands', () {
    for (final values in <List<double>>[
      [],
      List.filled(24, 0),
      List.filled(24, 1),
      List.generate(24, (i) => i.isEven ? 1 : 0),
      [double.nan, double.infinity, -1, 5],
    ]) {
      final metric = buildSpectrumContour(const Size(240, 50), values)
          .computeMetrics()
          .single;
      var lastX = -1.0;
      for (var offset = 0.0; offset < metric.length; offset += .25) {
        final point = metric.getTangentForOffset(offset)!.position;
        expect(point.dx.isFinite && point.dy.isFinite, isTrue);
        expect(point.dx, inInclusiveRange(0, 240));
        expect(point.dy, inInclusiveRange(0, 50));
        expect(point.dx, greaterThanOrEqualTo(lastX - .0001));
        lastX = point.dx;
      }
    }
  });
  test('curve tangent is continuous at a high narrow peak rather than a corner',
      () {
    final metric = buildSpectrumContour(const Size(240, 50), [0, 1, 0])
        .computeMetrics()
        .single;
    var low = 0.0, high = metric.length;
    for (var i = 0; i < 30; i++) {
      final middle = (low + high) / 2;
      if (metric.getTangentForOffset(middle)!.position.dx < 15) {
        low = middle;
      } else {
        high = middle;
      }
    }
    final location = (low + high) / 2;
    final before = metric.getTangentForOffset(location - .01)!.vector;
    final after = metric.getTangentForOffset(location + .01)!.vector;
    expect(before.dx * after.dx + before.dy * after.dy, greaterThan(.995));
  });
}
