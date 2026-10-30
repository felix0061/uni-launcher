import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 卡片阴影预烘焙（B2）。
///
/// 现状：每张卡每帧要在光栅阶段做一次 `BoxShadow` 高斯（`blurRadius` 20dp /
/// 12dp，Adreno 530 上实测页面级 5-7ms）。卡片数据一变，整层（含模糊）
/// 就重新光栅一次，而卡片正是最常变化的东西。
///
/// 这里把它改成：按「尺寸 + 圆角 + 颜色 + 模糊 + 偏移」烘焙一张位图，
/// 之后每帧只做一次 `drawImageRect`。
///
/// 只在优化模式（`PerfFlags.bakedCards`）下启用；关闭时调用方继续用原来的
/// `BoxDecoration.boxShadow`，视觉完全一致。
class BakedShadow extends StatefulWidget {
  final BorderRadius borderRadius;
  final Color color;
  final double blur, dy;
  final Widget child;
  const BakedShadow(
      {super.key,
      required this.borderRadius,
      required this.color,
      required this.blur,
      required this.dy,
      required this.child});
  @override
  State<BakedShadow> createState() => _BakedShadowState();
}

class _BakedShadowState extends State<BakedShadow> {
  static final Map<String, _BakedEntry> _cache = {};
  static const int _maxEntries = 12;

  ui.Image? image;
  String? key;

  /// 阴影位图约定：以卡片左上角为原点向左上各外扩 [blur]，向下扩
  /// `blur + dy`，所以位图尺寸是 `w + 2*blur` × `h + 2*blur + dy`。
  static Future<ui.Image> _bake(double w, double h, double radius, Color color,
      double blur, double dy) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(blur, blur + dy, w, h);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur));
    return recorder
        .endRecording()
        .toImage((w + 2 * blur).ceil(), (h + 2 * blur + dy).ceil());
  }

  void _scheduleBake(Size size) {
    final shape = widget.borderRadius;
    final signature =
        '${size.width.round()}x${size.height.round()}|${shape.topLeft.x.round()}|'
        '${widget.color.toARGB32()}|${widget.blur}|${widget.dy}';
    if (signature == key) return;
    final cached = _cache[signature];
    if (cached != null) {
      // 命中缓存时直接在当前 build 内换用位图，不 setState（build 期间禁止）。
      image = cached.image;
      key = signature;
      return;
    }
    image = null;
    key = signature;
    final radius = shape.topLeft.x;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || key != signature) return;
      _bake(size.width, size.height, radius, widget.color, widget.blur,
              widget.dy)
          .then((baked) {
        if (!mounted) {
          baked.dispose();
          return;
        }
        if (_cache.length >= _maxEntries) _cache.clear();
        _cache[signature] = _BakedEntry(baked);
        if (key == signature) setState(() => image = baked);
      }).catchError((Object _) {
        // 烘焙失败就继续用 BoxShadow 回退，不影响功能。
      });
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final size = box.biggest;
        if (!size.isFinite || size.isEmpty) return widget.child;
        _scheduleBake(size);
        final baked = image;
        if (baked != null) {
          return DecoratedBox(
              decoration: _BakedShadowDecoration(
                  image: baked, blur: widget.blur, dy: widget.dy),
              child: widget.child);
        }
        return DecoratedBox(
            decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                boxShadow: [
                  BoxShadow(
                      color: widget.color,
                      offset: Offset(0, widget.dy),
                      blurRadius: widget.blur)
                ]),
            child: widget.child);
      });
}

class _BakedEntry {
  final ui.Image image;
  const _BakedEntry(this.image);
}

/// 把烘焙好的阴影位图按 `BoxShadow` 的语义绘制在卡片外侧。
/// 不走 `Decoration.paint`（新版 Flutter 要求实现 `createBoxPainter`），
/// 而是自己给一个 BoxPainter：`DecoratedBox` 会用它绘制，且绘制范围不受
/// 组件边界裁剪，正好覆盖原来阴影外扩的区域。
class _BakedShadowDecoration extends Decoration {
  final ui.Image image;
  final double blur, dy;
  const _BakedShadowDecoration(
      {required this.image, required this.blur, required this.dy});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _BakedShadowPainter(image, blur, dy);

  @override
  EdgeInsetsGeometry get padding => EdgeInsets.zero;

  @override
  bool operator ==(Object other) =>
      other is _BakedShadowDecoration &&
      other.image == image &&
      other.blur == blur &&
      other.dy == dy;

  @override
  int get hashCode => Object.hash(image, blur, dy);
}

class _BakedShadowPainter extends BoxPainter {
  final ui.Image image;
  final double blur, dy;
  const _BakedShadowPainter(this.image, this.blur, this.dy);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    final src =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(offset.dx - blur, offset.dy - blur,
        size.width + 2 * blur, size.height + 2 * blur + dy);
    canvas.drawImageRect(
        image,
        src,
        dst,
        Paint()
          ..filterQuality = FilterQuality.low
          ..isAntiAlias = true);
  }
}
