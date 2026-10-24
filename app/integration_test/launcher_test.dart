import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uni_launcher/main.dart' as app;
import 'package:uni_launcher/launcher_app.dart';
import 'package:uni_launcher/model/appearance.dart';
import 'package:uni_launcher/widgets/glass_surface.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Flutter launcher on Android 9 with persisted blur control',
      (tester) async {
    final checks = <String>[];
    void verify(String name, bool ok) {
      expect(ok, true, reason: name);
      checks.add(name);
    }

    Future<void> settle() async {
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await app.main();
    await settle();
    final c = tester.widget<LauncherApp>(find.byType(LauncherApp)).controller;
    c.resetLayout();
    c.setAppearance(const Appearance(mode: 'dark'));
    await c.command('demo-mode', enabled: true);
    await c.command('hide-navigation', enabled: false);
    await settle();
    await binding.convertFlutterSurfaceToImage();
    await settle();
    verify('Flutter home cards rendered',
        find.byKey(const ValueKey('nav-1')).evaluate().length == 1);
    verify('Blur defaults off with no BackdropFilter',
        find.byType(BackdropFilter).evaluate().isEmpty);
    final dock = tester.getRect(find.byKey(const ValueKey('bottom-dock')));
    final window = tester.view.physicalSize / tester.view.devicePixelRatio;
    verify('Desktop fills the usable emulator window',
        dock.right > window.width * .95 && dock.bottom > window.height * .9);
    verify('Android app list arrives through platform channel',
        (c.native.value['apps'] as List).isNotEmpty);
    await binding.takeScreenshot('flutter-home-dark');
    final keys = [
      'home',
      'all-apps',
      'climate',
      'play-pause',
      'music-info',
      'vehicle',
      'camera'
    ];
    final positions =
        keys.map((k) => tester.getCenter(find.byKey(ValueKey(k))).dx).toList();
    verify(
        'Bottom dock follows requested order',
        List.generate(
                positions.length - 1, (i) => positions[i] < positions[i + 1])
            .every((v) => v));
    await tester.longPress(find.byKey(const ValueKey('home')));
    await settle();
    verify('Holding Home enters desktop settings', c.settings);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('glass-switch')), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('glass-switch')));
    await settle();
    verify(
        'Blur switch creates clipped Flutter filters',
        c.appearance.glass &&
            find.byType(BackdropFilter).evaluate().isNotEmpty);
    await c.persist();
    final saved = await c.gateway.bootstrap();
    verify('Blur setting committed to Android preferences',
        jsonDecode(saved['savedDesign'])['preferences']['glass'] == true);
    await binding.takeScreenshot('flutter-settings-blur-on');
    await tester.tap(find.byKey(const ValueKey('glass-switch')));
    await settle();
    verify('Disabling blur removes every filter',
        !c.appearance.glass && find.byType(BackdropFilter).evaluate().isEmpty);
    c.setAppearance(
        c.appearance.copyWith(mode: 'light', palette: 'blue', radius: 0));
    c.home();
    await settle();
    verify('Light theme and zero radius applied',
        c.appearance.mode == 'light' && c.appearance.radius == 0);
    await binding.takeScreenshot('flutter-home-light-square');
    await tester.longPress(find.byKey(const ValueKey('music-1')));
    await settle();
    verify('Card hold opens edit mode', c.editing);
    await tester.tap(find.byKey(const ValueKey('add-card')));
    await settle();
    await tester.tap(find.byKey(const ValueKey('add-air')));
    await settle();
    verify('Card library allocates page when full',
        c.page == 2 && c.pageCount == 3 && c.cards.length == 8);
    final air = c.cards.last,
        grid = tester.getSize(find.byKey(const ValueKey('card-grid')));
    await tester.drag(
        find.byKey(ValueKey('move-${air.id}')), Offset(grid.width / 12 * 2, 0));
    await settle();
    verify('Touch drag moves card on grid', c.cards.last.x == 2);
    await tester.drag(find.byKey(ValueKey('resize-${air.id}')),
        Offset(grid.width / 12, grid.height / 6));
    await settle();
    verify('Touch resize updates card spans',
        c.cards.last.w == 5 && c.cards.last.h == 4);
    await tester.tap(find.byKey(const ValueKey('finish-edit')));
    await settle();
    await c.persist();
    final layout = await c.gateway.bootstrap();
    verify('Edited card layout committed to Android preferences',
        (jsonDecode(layout['savedDesign'])['cards'] as List).length == 8);
    await binding.takeScreenshot('flutter-card-edited');
    c.home();
    await settle();
    await tester.tap(find.byKey(const ValueKey('all-apps')));
    await settle();
    verify('Real installed application drawer opens',
        find.text('全部应用').evaluate().isNotEmpty);
    await binding.takeScreenshot('flutter-apps');
    await tester.tap(find.byTooltip('关闭应用列表'));
    await settle();
    await c.command('temp-up', zone: 'left');
    await settle();
    verify('Native climate simulator confirms command',
        (c.native.value['climate'] as Map)['left'] == 23.0);
    await tester.tap(find.byKey(const ValueKey('climate')));
    await settle();
    await binding.takeScreenshot('flutter-climate');
    await tester.tap(find.byTooltip('关闭空调'));
    await settle();
    await c.command('demo-mode', enabled: false);
    await settle();
    verify('Live mode removes illustrative navigation',
        find.text('600 米后右转').evaluate().isEmpty);
    verify(
        'Unavailable live climate is disabled',
        tester
                .widgetList<IconAction>(find.byType(IconAction))
                .firstWhere((w) => w.label == '升高主驾温度')
                .onTap ==
            null);
    await binding.takeScreenshot('flutter-live-unavailable');
    c.openSettings();
    await settle();
    await tester.tap(find.byKey(const ValueKey('hide-navigation')));
    await settle();
    verify('Native navigation setting applied',
        c.native.value['hideNavigation'] == true);
    await tester.tap(find.byKey(const ValueKey('hide-navigation')));
    await settle();
    verify('Native navigation setting restored',
        c.native.value['hideNavigation'] == false);
    c.setAppearance(c.appearance
        .copyWith(mode: 'dark', palette: 'mint', radius: 28, glass: true));
    await c.persist();
    c.home();
    await settle();
    verify('No Flutter rendering exception', tester.takeException() == null);
    binding.reportData = {
      ...?binding.reportData,
      'renderer': 'Flutter Android',
      'api': 28,
      'checks': checks,
      'passed': checks.length,
      'glassDefault': false,
      'carVerification': 'pending',
      'performance': 'Functional emulator checks; no real-car performance claim'
    };
  });
}
