import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uni_launcher/main.dart' as app;
import 'package:uni_launcher/launcher_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('shared engines release idle panels and task snapshots',
      (t) async {
    await app.main();
    await t.pumpAndSettle();
    final c = t.widget<LauncherApp>(find.byType(LauncherApp)).controller;
    final original = await c.gateway.bootstrap();
    final wasEnabled = (original['globalDock'] as Map)['enabled'] == true;
    Future<Map> dockUntil(bool Function(Map) condition) async {
      Map dock = {};
      for (var i = 0; i < 70; i++) {
        await t.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        dock = (await c.gateway.bootstrap())['globalDock'] as Map;
        if (condition(dock)) return dock;
      }
      throw StateError('Dock did not settle: $dock');
    }

    try {
      await dockUntil((d) => d['allowed'] == true);
      await c.command('global-dock', enabled: true);
      final first = await dockUntil(
          (d) => d['running'] == true && d['rendering'] == true);
      expect(first['liveFlutterEngines'], 2);
      final relayouts = first['dockRelayouts'];
      for (var cycle = 0; cycle < 4; cycle++) {
        await c.command('show-dock-panel', value: 'apps');
        final opened = await dockUntil(
            (d) => d['panelReady'] == true && d['panel'] == 'apps');
        expect(opened['liveFlutterEngines'], 3);
        await c.command('show-recents');
        await dockUntil(
            (d) => d['recentsReady'] == true && d['panel'] == 'recents');
        await c.command('dismiss-dock-panel');
        final closed = await dockUntil((d) => d['expanded'] == false);
        expect(closed['recentSnapshotCount'], 0);
        expect(closed['dockRelayouts'], relayouts);
      }
      final idle = await dockUntil((d) => d['panelEngineAlive'] == false);
      expect(idle['liveFlutterEngines'], 2);
      await c.command('show-dock-panel', value: 'climate');
      final reopened = await dockUntil(
          (d) => d['panelReady'] == true && d['panel'] == 'climate');
      expect(reopened['liveFlutterEngines'], 3);
      expect(reopened['dockRelayouts'], relayouts);
      await c.command('dismiss-dock-panel');
      await dockUntil((d) => d['panelEngineAlive'] == false);
      binding.reportData = {
        'cycles': 4,
        'activeEngines': 3,
        'idleEngines': 2,
        'idlePanelReleased': true,
        'nativeRecentsPurged': true,
        'dockRelayoutsUnchanged': true,
        'panelRecreated': true,
      };
    } finally {
      await c.command('global-dock', enabled: wasEnabled);
    }
  });
}
