import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uni_launcher/main.dart' as app;
import 'package:uni_launcher/launcher_app.dart';
import 'package:uni_launcher/widgets/glass_surface.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Global dock controls and full-width home dock', (t) async {
    await app.main();
    await t.pumpAndSettle();
    final c = t.widget<LauncherApp>(find.byType(LauncherApp)).controller;
    await c.command('demo-mode', enabled: true);
    c.home();
    await t.pumpAndSettle();
    final dock = t.getRect(find.byKey(const ValueKey('bottom-dock')));
    final size = t.view.physicalSize / t.view.devicePixelRatio;
    expect(dock.left, 0);
    expect(dock.right, size.width);
    expect(dock.bottom,
        (c.native.value['viewportHeightPx'] as num) / t.view.devicePixelRatio);
    final surface = t.widget<GlassSurface>(find
        .descendant(
            of: find.byKey(const ValueKey('bottom-dock')),
            matching: find.byType(GlassSurface))
        .first);
    expect(surface.radius, 0);
    expect(surface.shadow, false);
    c.openSettings();
    c.tab('sources');
    await t.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await t.scrollUntilVisible(find.byKey(const ValueKey('global-dock')), 250,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    expect((c.native.value['globalDock'] as Map)['allowed'], true);
    expect(c.native.value['systemNavigationGranted'], true);
    await t.tap(find.byKey(const ValueKey('system-navigation-hidden')));
    await t.pumpAndSettle();
    expect(c.native.value['systemNavigationHidden'], true);
    await t.tap(find.byKey(const ValueKey('system-navigation-hidden')));
    await t.pumpAndSettle();
    expect(c.native.value['systemNavigationHidden'], false);
    final enabled = (c.native.value['globalDock'] as Map)['enabled'] == true;
    if (!enabled) await t.tap(find.byKey(const ValueKey('global-dock')));
    for (int i = 0;
        i < 30 && (c.native.value['globalDock'] as Map)['running'] != true;
        i++) {
      await t.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect((c.native.value['globalDock'] as Map)['running'], true);
    expect((c.native.value['globalDock'] as Map)['visible'], false,
        reason: 'Home keeps one inline dock; global copy is hidden');
    await binding.takeScreenshot('global-dock-settings');
    c.home();
    await t.pumpAndSettle();
    await binding.takeScreenshot('global-dock-home');
    expect(t.takeException(), null);
    final screenshots = binding.reportData?['screenshots'];
    binding.reportData = {
      'screenshots': screenshots,
      'passed': 10,
      'checks': [
        'full-width',
        'zero bottom gap',
        'square outer surface',
        'no outer shadow',
        'system hide',
        'system restore',
        'overlay grant',
        'service starts',
        'no duplicate on home',
        'no Flutter exception'
      ],
      'externalAppVerification': 'next: emulator adb UI script'
    };
  });
}
