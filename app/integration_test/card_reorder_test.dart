import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uni_launcher/controller/launcher_controller.dart';
import 'package:uni_launcher/launcher_app.dart';
import 'package:uni_launcher/model/card_layout.dart';
import '../test/fake_gateway.dart';

List<LauncherCard> _page(int page) => [
      for (var i = 0; i < 6; i++)
        LauncherCard('$page-$i', i == 0 ? 'trafficLight' : 'clock',
            i == 0 ? '红绿灯' : '时钟 $i', i % 3 * 4, i ~/ 3 * 3, 4, 3, page)
    ];

/// Uses the production workspace/widgets and Android renderer with explicitly
/// synthetic data. Never writes vehicle settings, controls or OEM app state.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android workspace reorder, resize, cross-page and rollback',
      (t) async {
    final g = FakeGateway();
    final controller = LauncherController(g);
    await controller.initialize();
    controller.cards = _page(0);
    controller.pageCount = 1;
    controller.setAppearance(controller.appearance.copyWith(mode: 'dark'),
        save: false);
    controller.beginEdit();
    await t.pumpWidget(LauncherApp(controller: controller));
    await t.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await t.pumpAndSettle();
    await binding.takeScreenshot('card-reorder-initial');
    final checks = <String>[];
    void check(String label, bool condition) {
      expect(condition, isTrue, reason: label);
      checks.add(label);
    }

    Rect grid() => t.getRect(find.byKey(const ValueKey('grid-bounds')));
    Future<TestGesture> move(String id, Offset delta) async {
      final gesture =
          await t.startGesture(t.getCenter(find.byKey(ValueKey('move-$id'))));
      await gesture.moveBy(delta);
      await t.pump();
      await t.pump(const Duration(milliseconds: 170));
      return gesture;
    }

    final drag = await move('0-0', Offset((grid().width + 20) / 3, 0));
    check(
        'hover previews occupied-cell displacement without committing',
        controller.placementPreview?.first.x == 4 &&
            controller.cards.first.x == 0);
    await t.pumpAndSettle();
    await binding.takeScreenshot('card-reorder-preview');
    check('bounded drag bitmap is displayed',
        find.byType(RawImage).evaluate().isNotEmpty);
    await drag.up();
    await t.pumpAndSettle();
    check(
        'release swaps both cards with no overlap or deletion',
        controller.cards.first.x == 4 &&
            controller.cards[1].x == 0 &&
            controller.cards.length == 6 &&
            validLayout(controller.cards));
    await binding.takeScreenshot('card-reorder-dropped');
    controller.finishEdit();
    await controller.persist();
    await t.pumpAndSettle();
    check('drop is saved by the existing editor persistence',
        (jsonDecode(g.saved!)['cards'] as List).first['x'] == 4);

    controller.cards = _page(0);
    controller.beginEdit();
    await t.pumpAndSettle();
    final blocked = await t
        .startGesture(t.getCenter(find.byKey(const ValueKey('resize-0-0'))));
    await blocked.moveBy(Offset(0, (grid().height + 20) / 6));
    await t.pump();
    check('full grid rejects expansion and shows invalid preview',
        !controller.placementValid);
    await binding.takeScreenshot('card-reorder-resize-blocked');
    await blocked.up();
    await t.pumpAndSettle();
    check('invalid resize restores original dimensions',
        controller.cards.first.h == 3);

    controller.cards = [
      const LauncherCard('0-0', 'trafficLight', '红绿灯', 0, 0, 4, 2, 0),
      const LauncherCard('0-1', 'clock', '时钟 1', 4, 0, 4, 3, 0),
      const LauncherCard('0-2', 'clock', '时钟 2', 8, 0, 4, 3, 0),
    ];
    controller.setAppearance(controller.appearance, save: false);
    await t.pumpAndSettle();
    final resize = await t
        .startGesture(t.getCenter(find.byKey(const ValueKey('resize-0-0'))));
    await resize
        .moveBy(Offset((grid().width + 20) / 3, (grid().height + 20) / 6));
    await t.pump();
    check(
        'corner handle previews 4x2 to 8x3 layout with displaced neighbour',
        controller.placementValid &&
            controller.placementTarget?.w == 8 &&
            controller.placementTarget?.h == 3);
    await t.pumpAndSettle();
    check(
        'resize preview moves the neighbouring widget out of the target area',
        t.getRect(find.byKey(const ValueKey('position-0-1'))).top >
            t.getRect(find.byKey(const ValueKey('position-0-0'))).top + 30);
    await binding.takeScreenshot('card-reorder-resize-preview');
    await resize.up();
    await t.pumpAndSettle();
    check('resized layout commits and remains valid',
        controller.cards.first.w == 8 && validLayout(controller.cards));

    controller.cards = [..._page(0), ..._page(1)];
    controller.pageCount = 2;
    controller.setAppearance(controller.appearance, save: false);
    await t.pumpAndSettle();
    final element = t.element(find.byKey(const ValueKey('0-0')));
    final start = t.getCenter(find.byKey(const ValueKey('move-0-0')));
    final edge = await t.startGesture(start);
    await edge.moveTo(Offset(grid().right - 8, start.dy));
    await t.pump();
    await t.pump(const Duration(milliseconds: 460));
    await t.pump();
    await t.pump(const Duration(milliseconds: 180));
    check('same pointer continues into the next page',
        controller.page == 1 && controller.placing);
    await binding.takeScreenshot('card-reorder-cross-page');
    await edge.up();
    await t.pumpAndSettle();
    check(
        'cross-page drop preserves source widget element',
        controller.cards.first.page == 1 &&
            identical(t.element(find.byKey(const ValueKey('0-0'))), element));
    check('all source and destination cards survive',
        controller.cards.length == 12 && validLayout(controller.cards));
    controller.cancelEdit();
    await t.pumpAndSettle();
    check(
        'editor cancellation restores edit-session layout across both pages',
        controller.cards.length == 6 &&
            controller.cards.first.x == 0 &&
            controller.pageCount == 1);
    check('no framework exceptions', t.takeException() == null);
    await t.pumpWidget(const SizedBox());
    controller.dispose();
    await g.dispose();
    binding.reportData = {
      'source':
          'production Flutter widgets, synthetic gateway; no vehicle operations',
      'checks': checks,
      'screenshots': binding.reportData?['screenshots']
    };
  });
}
