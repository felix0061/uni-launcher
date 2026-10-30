import 'package:flutter_test/flutter_test.dart';
import 'package:uni_launcher/widgets/embedded_navigation.dart';

/// 「嵌入地图缩放」的比例规则：虚拟显示密度不能低于 141dpi（否则会靠近
/// ldpi 资源桶），在这个前提下尽量缩；下限 0.6 避免画面明显发虚。
void main() {
  test('160dpi 车机（IP753）取 0.88125，虚拟显示为 141dpi', () {
    final scale = mapTextureScaleFor(160);
    expect(scale, closeTo(0.88125, 1e-6));
    expect((160 * scale).round(), mapTextureMinDpi);
  });

  test('高密度车机自动缩得更多，但守住 0.6 下限', () {
    expect(mapTextureScaleFor(240), 0.6); // 141/240=0.5875 → 下限
    expect(mapTextureScaleFor(320), 0.6);
    expect(mapTextureScaleFor(200), closeTo(0.705, 0.001));
  });

  test('低密度车机不缩放（缩了必然进 ldpi）', () {
    expect(mapTextureScaleFor(120), 1.0);
    expect(mapTextureScaleFor(100), 1.0);
  });

  test('只要发生缩放，虚拟显示密度就 ≥ 141', () {
    for (final dpi in [141.0, 160.0, 180.0, 213.0, 240.0, 320.0, 480.0]) {
      final scale = mapTextureScaleFor(dpi);
      expect(dpi * scale, greaterThanOrEqualTo(140.9),
          reason: '$dpi dpi 缩放 ${scale.toStringAsFixed(4)} 后为 ${dpi * scale}');
    }
  });

  test('非法密度回退到不缩放', () {
    expect(mapTextureScaleFor(0), 1.0);
    expect(mapTextureScaleFor(-1), 1.0);
  });
}
