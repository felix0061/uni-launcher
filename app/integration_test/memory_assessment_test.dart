import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uni_launcher/main.dart' as app;
import 'package:uni_launcher/launcher_app.dart';

/// App code is unchanged. This entrypoint exposes only test checkpoint metadata
/// so the host can collect PSS and post-GC VM heaps while interactions pause.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('bounded retained memory under repeated desktop and overlay use',
      (t) async {
    await app.main();
    await t.pumpAndSettle();
    final c = t.widget<LauncherApp>(find.byType(LauncherApp)).controller;
    final originalAppearance = c.appearance;
    final original = await c.gateway.bootstrap();
    final wasEnabled = (original['globalDock'] as Map)['enabled'] == true;
    var phase = 'starting';
    var nativeOnly = false;
    Completer<void>? gate;
    Map<String, dynamic> snapshot = {};
    developer.registerExtension('ext.uni.memoryProbe', (_, params) async {
      if (params.containsKey('nativeOnly'))
        nativeOnly = params['nativeOnly'] == 'true';
      if (params['release'] == phase && gate?.isCompleted == false)
        gate!.complete();
      return developer.ServiceExtensionResponse.result(jsonEncode({
        'phase': phase,
        'waiting': gate != null && !gate!.isCompleted,
        ...snapshot,
      }));
    });
    Future<void> settle() async {
      await t.pumpAndSettle();
      await t.pump(const Duration(milliseconds: 100));
    }

    Future<Map> dockUntil(bool Function(Map) matches) async {
      for (var i = 0; i < 100; i++) {
        await t.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final dock = (await c.gateway.bootstrap())['globalDock'] as Map;
        if (matches(dock)) return dock;
      }
      throw StateError('Global dock did not reach expected lifecycle state');
    }

    Future<void> checkpoint(String name) async {
      await settle();
      final native = await c.gateway.bootstrap();
      final images = PaintingBinding.instance.imageCache;
      snapshot = {
        'controllerCaches': c.imageCacheStats,
        'flutterImages': {
          'count': images.currentSize,
          'bytes': images.currentSizeBytes,
          'live': images.liveImageCount,
          'pending': images.pendingImageCount
        },
        'dock': native['globalDock'],
        'mapCount': 0,
        'navigationCanEmbed':
            (native['navigation'] as Map?)?['canEmbed'] == true,
      };
      phase = name;
      gate = Completer<void>();
      // The host reads VM usage AFTER GC, native PSS, and surviving state counts.
      await gate!.future.timeout(const Duration(seconds: 90));
      gate = null;
    }

    Future<void> inlineCycle() async {
      for (final entry in [
        ('all-apps', '关闭应用列表'),
        ('music-info', '关闭音乐详情'),
        ('climate', '关闭空调')
      ]) {
        await t.tap(find.byKey(ValueKey(entry.$1)).last);
        await settle();
        await t.tap(find.byTooltip(entry.$2));
        await settle();
      }
      await c.switchPage(1);
      await settle();
      await c.switchPage(0);
      await settle();
      c.openSettings();
      await settle();
      c.home();
      await settle();
    }

    try {
      await c.command('global-dock', enabled: false);
      await c.command('demo-mode', enabled: true);
      c.setAppearance(c.appearance.copyWith(
          themeStyle: 'blueGlass', mode: 'dark', palette: 'blue', glass: true));
      c.home();
      await settle();
      await checkpoint('inline-cold');
      for (var i = 0; i < (nativeOnly ? 0 : 5); i++) await inlineCycle();
      await checkpoint('inline-warm');
      for (var batch = 1; batch <= (nativeOnly ? 0 : 3); batch++) {
        for (var i = 0; i < 15; i++) await inlineCycle();
        await checkpoint('inline-${batch * 15}');
      }
      await c.command('global-dock', enabled: true);
      await dockUntil((d) => d['running'] == true && d['rendering'] == true);
      await checkpoint('global-cold');
      for (var cycle = 1; cycle <= 8; cycle++) {
        for (final kind in ['apps', 'media', 'climate', 'recents']) {
          if (kind == 'recents') {
            await c.command('show-recents');
            await dockUntil(
                (d) => d['panel'] == kind && d['recentsReady'] == true);
          } else {
            await c.command('show-dock-panel', value: kind);
            await dockUntil(
                (d) => d['panel'] == kind && d['panelReady'] == true);
          }
        }
        if (cycle == 1 || cycle == 8) await checkpoint('global-open-$cycle');
        await c.command('dismiss-dock-panel');
        final idle = await dockUntil((d) => d['panelWindowAttached'] == false);
        expect(idle['liveFlutterEngines'], 3);
        expect(idle['recentSnapshotCount'], 0);
        if (cycle.isEven) await checkpoint('global-idle-$cycle');
      }
      await c.command('global-dock', enabled: false);
      await dockUntil(
          (d) => d['running'] == false && d['liveFlutterEngines'] == 1);
      await checkpoint('inline-after-global');
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(const Duration(seconds: 8));
        await checkpoint('idle-$i');
      }
      expect(t.takeException(), isNull);
      binding.reportData = {
        'version': '0.6.12',
        'inlineCycles': nativeOnly ? 0 : 50,
        'inlineModalOpens': nativeOnly ? 0 : 150,
        'settingsMounts': nativeOnly ? 0 : 50,
        'pageTransitions': nativeOnly ? 0 : 100,
        'overlayCycles': 8,
        'overlayPanelTransitions': 32,
        'realMapMeasured': false,
        'realMusicAppsMeasured': false,
        'scope':
            'API28 x86_64 profile/AOT; demo music and vehicle data; no map embedding privileges',
      };
    } finally {
      phase = 'complete';
      await c.command('global-dock', enabled: wasEnabled);
      await c.command('demo-mode', enabled: original['demo'] == true);
      c.setAppearance(originalAppearance);
      c.home();
      await c.persist();
    }
  }, timeout: const Timeout(Duration(minutes: 12)));
}
