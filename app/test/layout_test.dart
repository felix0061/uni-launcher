import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_launcher/controller/launcher_controller.dart';
import 'package:uni_launcher/model/appearance.dart';
import 'package:uni_launcher/model/card_layout.dart';
import 'fake_gateway.dart';

void main() {
  test('glass defaults off and migrates missing old preference', () {
    expect(const Appearance().glass, false);
    expect(Appearance.fromJson({'radius': 0}).glass, false);
  });
  test('radius accepts square corners and clamps range', () {
    expect(Appearance.fromJson({'radius': 0}).radius, 0);
    expect(Appearance.fromJson({'radius': 99}).radius, 40);
    expect(Appearance.fromJson({'radius': -2}).radius, 0);
  });
  test('invalid accent and mode fall back to safe defaults', () {
    final a = Appearance.fromJson(
        {'custom': 'red;', 'palette': 'unknown', 'mode': 'other'});
    expect(a.custom, '#38A4A0');
    expect(a.mode, 'system');
    expect(a.palette, 'mint');
  });
  test('default OEM layout has no overlap', () {
    expect(validLayout(defaultCards()), true);
    expect(defaultCards().length, 8);
  });
  test('rejects collision, bounds, duplicate identifiers and unknown type', () {
    final cards = defaultCards();
    expect(validLayout([...cards, cards.first]), false);
    expect(validLayout([cards.first.copyWith(x: 11)]), false);
    expect(validLayout([const LauncherCard('x', 'unknown', '', 0, 0, 4, 2, 0)]),
        false);
  });
  test('editing preserves committed layout on cancel', () async {
    final gateway = FakeGateway(), c = LauncherController(gateway);
    await c.initialize();
    c.beginEdit();
    c.remove('weather-1');
    expect(c.cards.length, 7);
    c.cancelEdit();
    expect(c.cards.length, 8);
    c.dispose();
    await gateway.dispose();
  });
  test('adding to full page allocates page; cancel restores page count',
      () async {
    final g = FakeGateway(), c = LauncherController(g);
    await c.initialize();
    c.beginEdit();
    expect(c.add('air'), true);
    expect(c.pageCount, 3);
    expect(c.page, 2);
    c.cancelEdit();
    expect(c.pageCount, 2);
    c.dispose();
    await g.dispose();
  });
  test('empty trailing editor pages are not persisted or restored', () async {
    final g = FakeGateway(), c = LauncherController(g);
    await c.initialize();
    c.beginEdit();
    c.newPage();
    expect(c.pageCount, 3);
    c.finishEdit();
    expect(c.pageCount, 2);
    expect(c.page, 1);
    await c.persist();
    final saved = jsonDecode(g.saved!);
    saved['pageCount'] = 7;
    final next = FakeGateway()..state['savedDesign'] = jsonEncode(saved);
    final restored = LauncherController(next);
    await restored.initialize();
    expect(restored.pageCount, 2);
    c.dispose();
    restored.dispose();
    await g.dispose();
    await next.dispose();
  });
  test('glass and theme persist through native repository and reload',
      () async {
    final g = FakeGateway(), c = LauncherController(g);
    await c.initialize();
    c.setAppearance(
        c.appearance.copyWith(glass: true, palette: 'blue', radius: 0));
    await c.persist();
    expect(jsonDecode(g.saved!)['preferences']['glass'], true);
    final next = FakeGateway();
    next.state['savedDesign'] = g.saved;
    final loaded = LauncherController(next);
    await loaded.initialize();
    expect(loaded.appearance.glass, true);
    expect(loaded.appearance.radius, 0);
    expect(loaded.appearance.palette, 'blue');
    c.dispose();
    loaded.dispose();
    await g.dispose();
    await next.dispose();
  });
}
