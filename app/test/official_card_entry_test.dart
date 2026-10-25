import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_launcher/controller/launcher_controller.dart';
import 'package:uni_launcher/model/appearance.dart';
import 'package:uni_launcher/model/card_layout.dart';
import 'package:uni_launcher/theme/launcher_theme.dart';
import 'package:uni_launcher/widgets/card_content.dart';
import 'package:uni_launcher/widgets/glass_surface.dart';
import 'fake_gateway.dart';

void main() {
  for (final type in ['weather', 'calendar', 'member', 'cleanup']) {
    testWidgets('$type has an OEM entry without claiming live fields',
        (t) async {
      final g = FakeGateway()..state['demo'] = false;
      final c = LauncherController(g);
      await c.initialize();
      final style = SurfaceStyle.from(const Appearance(mode: 'dark'), true);
      final card =
          LauncherCard('entry', type, specFor(type).label, 0, 0, 4, 3, 0);
      await t.pumpWidget(MaterialApp(
          theme: launcherTheme(style),
          home: Scaffold(
              body: Center(
                  child: SizedBox(
                      width: 360,
                      height: type == 'member' ? 420 : 230,
                      child: GlassSurface(
                          padding: EdgeInsets.zero,
                          child: CardContent(card: card, controller: c)))))));
      await t.pumpAndSettle();
      final button = find.widgetWithText(
          OutlinedButton,
          switch (type) {
            'member' => '打开账号中心',
            'cleanup' => '打开清理',
            'calendar' => '打开日历',
            _ => '打开天气',
          });
      expect(button, findsOneWidget);
      expect(find.textContaining('未同步'), findsWidgets);
      await t.tap(button);
      await t.pumpAndSettle();
      expect(g.commands.last['action'], 'official-widget');
      expect(g.commands.last['value'], type);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      c.dispose();
      await g.dispose();
    });
  }
  testWidgets('calendar renders system date and upcoming agenda', (t) async {
    final g = FakeGateway()
      ..state['demo'] = false
      ..state['calendar'] = {
        'available': true,
        'authorized': true,
        'day': 26,
        'weekday': '星期一',
        'monthLabel': '2026 年 10 月',
        'eventAvailable': true,
        'title': '车辆保养',
        'location': '领克中心',
        'beginMs': DateTime(2026, 10, 26, 10, 30).millisecondsSinceEpoch,
      };
    final c = LauncherController(g);
    await c.initialize();
    final style = SurfaceStyle.from(const Appearance(mode: 'dark'), true);
    const card = LauncherCard('calendar-live', 'calendar', '日历', 0, 0, 4, 3, 0);
    await t.pumpWidget(MaterialApp(
        theme: launcherTheme(style),
        home: Scaffold(
            body: SizedBox(
                width: 480,
                height: 360,
                child: GlassSurface(
                    padding: EdgeInsets.zero,
                    child: CardContent(card: card, controller: c))))));
    await t.pumpAndSettle();
    expect(find.text('26'), findsOneWidget);
    expect(find.text('星期一'), findsOneWidget);
    expect(find.text('车辆保养'), findsOneWidget);
    expect(find.text('10:30 · 领克中心'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    c.dispose();
    await g.dispose();
  });
}
