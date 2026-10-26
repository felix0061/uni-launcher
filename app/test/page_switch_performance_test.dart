import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_launcher/widgets/page_transition.dart';

class _Counts {
  int layouts = 0, paints = 0;
}

class _Probe extends LeafRenderObjectWidget {
  final _Counts counts;
  const _Probe(this.counts);
  @override
  RenderBox createRenderObject(BuildContext context) => _RenderProbe(counts);
}

class _RenderProbe extends RenderBox {
  final _Counts counts;
  _RenderProbe(this.counts);
  @override
  void performLayout() {
    counts.layouts++;
    size = constraints.biggest;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    counts.paints++;
    // Deliberately overflow: the page frame must clip this paint.
    context.canvas.drawRect(
        (offset - const Offset(50, 50)) & (size + const Offset(100, 100)),
        Paint()..color = Colors.red);
  }
}

void main() {
  testWidgets('retained pages defer hidden constraint work until reveal',
      (t) async {
    Future<List<int>> measure(bool retained) async {
      final counts = List.generate(3, (_) => _Counts());
      final children = [for (final c in counts) _Probe(c)];
      Future<void> show(double width, int page) => t.pumpWidget(MaterialApp(
          home: Center(
              child: SizedBox(
                  width: width,
                  height: 300,
                  child: retained
                      ? DesktopPageStack(
                          page: page, effect: 'none', children: children)
                      : Stack(fit: StackFit.expand, children: [
                          for (int i = 0; i < children.length; i++)
                            Offstage(offstage: i != page, child: children[i])
                        ])))));
      await show(500, 0);
      for (final c in counts) {
        c.layouts = 0;
        c.paints = 0;
      }
      for (int i = 1; i <= 12; i++) {
        await show(500 + i.toDouble(), 0);
      }
      final hiddenLayouts = counts[1].layouts + counts[2].layouts;
      expect(counts[0].layouts, 12);
      expect(counts[1].paints + counts[2].paints, 0);
      await show(512, 1);
      expect(t.getSize(find.byWidget(children[1])), const Size(512, 300));
      expect(counts[1].paints, greaterThan(0));
      await t.pumpWidget(const SizedBox.shrink());
      return [hiddenLayouts];
    }

    final before = await measure(false), after = await measure(true);
    expect(before.single, 24);
    expect(after.single, 0);
    debugPrint(
        '12 constraint frames / 2 hidden pages: Offstage=${before.single}, retained=${after.single} hidden layouts');
  });

  testWidgets('animation frames do no extra page layout and paint only target',
      (t) async {
    final counts = List.generate(3, (_) => _Counts());
    final children = [for (final c in counts) _Probe(c)];
    Future<void> show(int page) => t.pumpWidget(MaterialApp(
        home:
            DesktopPageStack(page: page, effect: 'slide', children: children)));
    await show(0);
    await show(1);
    for (final c in counts) {
      c.layouts = 0;
      c.paints = 0;
    }
    for (int i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(counts.fold<int>(0, (n, c) => n + c.layouts), 0);
    expect(counts[0].paints + counts[2].paints, 0);
    await show(2);
    await t.pump(const Duration(milliseconds: 30));
    await show(0);
    await t.pumpAndSettle();
    expect(find.byWidget(children[0]), findsOneWidget);
    expect(find.byWidget(children[1]), findsNothing);
    expect(find.byWidget(children[2]), findsNothing);
    expect(t.takeException(), isNull);
  });
}
