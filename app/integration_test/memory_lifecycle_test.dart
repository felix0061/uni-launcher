import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uni_launcher/main.dart' as app;
import 'package:uni_launcher/launcher_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'shared engines reuse panel engine and release idle windows and task snapshots',
      (t) async {
    await app.main();
    await t.pumpAndSettle();
    final c = t.widget<LauncherApp>(find.byType(LauncherApp)).controller;
    var pressureRequested = false;
    final pressureApplied = Completer<void>();
    developer.registerExtension('ext.uni.lifecyclePressure', (_, params) async {
      if (params['release'] == 'true' && !pressureApplied.isCompleted)
        pressureApplied.complete();
      return developer.ServiceExtensionResponse.result(jsonEncode(
          {'waiting': pressureRequested && !pressureApplied.isCompleted}));
    });
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
      Object? panelIdentity;
      for (var cycle = 0; cycle < 4; cycle++) {
        await c.command('show-dock-panel', value: 'apps');
        final opened = await dockUntil(
            (d) => d['panelReady'] == true && d['panel'] == 'apps');
        expect(opened['liveFlutterEngines'], 3);
        panelIdentity ??= opened['panelEngineIdentity'];
        expect(opened['panelEngineIdentity'], panelIdentity);
        await c.command('show-recents');
        await dockUntil(
            (d) => d['recentsReady'] == true && d['panel'] == 'recents');
        await c.command('dismiss-dock-panel');
        final closed = await dockUntil((d) => d['expanded'] == false);
        expect(closed['recentSnapshotCount'], 0);
        expect(closed['dockRelayouts'], relayouts);
      }
      final idle = await dockUntil((d) => d['panelWindowAttached'] == false);
      expect(idle['liveFlutterEngines'], 3);
      await c.command('show-dock-panel', value: 'climate');
      final reopened = await dockUntil(
          (d) => d['panelReady'] == true && d['panel'] == 'climate');
      expect(reopened['liveFlutterEngines'], 3);
      expect(reopened['dockRelayouts'], relayouts);
      await c.command('dismiss-dock-panel');
      await dockUntil((d) => d['panelWindowAttached'] == false);
      pressureRequested = true;
      await pressureApplied.future.timeout(const Duration(seconds: 20));
      final trimmed = await dockUntil((d) => d['panelEngineAlive'] == false);
      expect(trimmed['liveFlutterEngines'], 2);
      await c.command('show-dock-panel', value: 'climate');
      final recovered = await dockUntil(
          (d) => d['panelReady'] == true && d['panel'] == 'climate');
      expect(recovered['liveFlutterEngines'], 3);
      expect(recovered['dockRelayouts'], relayouts);
      await c.command('dismiss-dock-panel');
      binding.reportData = {
        'cycles': 4,
        'activeEngines': 3,
        'idleEngines': 3,
        'idlePanelWindowReleased': true,
        'panelEngineReused': true,
        'nativeRecentsPurged': true,
        'dockRelayoutsUnchanged': true,
        'panelReattached': true,
        'lowMemoryReleasesIdleEngine': true,
        'panelReopensAfterPressure': true,
      };
    } finally {
      await c.command('global-dock', enabled: wasEnabled);
    }
  });
}
