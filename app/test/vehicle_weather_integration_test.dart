import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_launcher/controller/launcher_controller.dart';
import 'package:uni_launcher/launcher_app.dart';
import 'package:uni_launcher/model/vehicle_data.dart';
import 'package:uni_launcher/model/seat_control.dart';
import 'package:uni_launcher/model/weather_condition.dart';
import 'package:uni_launcher/theme/launcher_theme.dart';
import 'package:uni_launcher/model/appearance.dart';
import 'package:uni_launcher/widgets/weather_icon.dart';
import 'package:uni_launcher/widgets/embedded_navigation.dart';
import 'package:uni_launcher/widgets/card_content.dart';
import 'fake_gateway.dart';

void main() {
  test('Demo seats use simulator levels even with an unavailable vehicle map',
      () {
    final n = <String, dynamic>{
      'demo': true,
      'climate': {'driverHeat': 2, 'driverVent': 0, 'passengerHeat': 3},
      'vehicle': {'connected': false, 'fields': <String, dynamic>{}}
    };
    expect(SeatControlState.fromNative(n, 'driverHeat').level, 2);
    expect(SeatControlState.fromNative(n, 'driverVent').level, 0);
    expect(SeatControlState.fromNative(n, 'passengerHeat').level, 3);
    n['demo'] = false;
    expect(SeatControlState.fromNative(n, 'driverHeat').level, null);
  });
  test('Music source label follows the associated installed application', () {
    final n = <String, dynamic>{
      'media': {'source': 'com.tencent.qqmusic'},
      'apps': [
        {'package': 'com.tencent.qqmusic', 'label': 'QQ 音乐'}
      ]
    };
    expect(mediaSourceLabel(n), 'QQ 音乐');
    n['media'] = {};
    n['integrationPreferences'] = {'mediaPackage': 'com.tencent.qqmusic'};
    expect(mediaSourceLabel(n), 'QQ 音乐');
  });
  test(
      'All weather labels and stable IDs map, provider numeric codes stay unknown',
      () {
    for (final k in WeatherKind.values) {
      expect(WeatherKind.fromText(k.label), k);
      expect(WeatherKind.fromText(k.name), k);
    }
    expect(WeatherKind.fromText('小到中雨'), WeatherKind.moderateRain);
    expect(WeatherKind.fromText('晴转暴雪'), WeatherKind.blizzard);
    expect(WeatherKind.fromText('123456'), WeatherKind.unknown);
    expect(WeatherKind.fromText(null), WeatherKind.unknown);
    expect(WeatherKind.fromText('新天气代码'), WeatherKind.unknown);
  });
  testWidgets('Every weather icon paints visible pixels by day and night',
      (t) async {
    final signatures = <WeatherKind, int>{};
    for (final night in [false, true])
      for (final k in WeatherKind.values) {
        final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
        WeatherPainter(k, night, const Color(0xff71e4ce))
            .paint(canvas, const Size(128, 128));
        final picture = recorder.endRecording();
        final bytes = await t.runAsync(() async {
          final image = await picture.toImage(128, 128);
          final data =
              await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          image.dispose();
          return data!;
        });
        picture.dispose();
        final pixels = bytes!.buffer.asUint8List();
        int visible = 0, signature = 0;
        for (int i = 3; i < pixels.length; i += 4) {
          if (pixels[i] > 0) {
            visible++;
            signature = (signature + i * pixels[i]) & 0x7fffffff;
          }
        }
        expect(visible, greaterThan(100),
            reason: '${k.name} $night has visible vector artwork');
        if (!night) signatures[k] = signature;
      }
    expect(signatures[WeatherKind.clear],
        isNot(signatures[WeatherKind.partlyCloudy]));
    expect(signatures[WeatherKind.lightRain],
        isNot(signatures[WeatherKind.heavyRain]));
    expect(signatures[WeatherKind.lightSnow],
        isNot(signatures[WeatherKind.blizzard]));
    expect(signatures[WeatherKind.fog], isNot(signatures[WeatherKind.haze]));
    expect(signatures[WeatherKind.hot], isNot(signatures[WeatherKind.cold]));
  });
  test('Weather never fabricates live weather and tolerates unknown conditions',
      () {
    final empty = WeatherSnapshot.fromNative({'demo': false});
    expect(empty.temperature, null);
    expect(empty.condition, WeatherKind.unknown);
    final value = WeatherSnapshot.fromNative({
      'weather': {
        'available': true,
        'condition': '冻雨',
        'night': true,
        'temperature': -3,
        'city': '北京',
        'source': 'fixture'
      }
    });
    expect(value.condition, WeatherKind.freezingRain);
    expect(value.temperature, -3);
    expect(value.night, true);
  });
  test('Vehicle fields expire individually and disconnect removes readings',
      () {
    final n = <String, dynamic>{
      'vehicle': {
        'connected': true,
        'fields': {
          'left': {'valid': true, 'value': 22.5, 'updatedAtMs': 10000},
          'fan': {'valid': false, 'value': 5, 'updatedAtMs': 11000},
          'pressureFrontLeft': {
            'valid': true,
            'value': 246.0,
            'unit': 'raw',
            'updatedAtMs': 10000
          }
        }
      }
    };
    expect(VehicleField.fromNative(n, 'left', nowMs: 12000).display(), '22.5');
    expect(VehicleField.fromNative(n, 'left', nowMs: 16000).valid, false);
    expect(VehicleField.fromNative(n, 'fan', nowMs: 12000).display(), '—');
    expect(VehicleField.fromNative(n, 'pressureFrontLeft', nowMs: 12000).unit,
        'raw');
    (n['vehicle'] as Map)['connected'] = false;
    expect(VehicleField.fromNative(n, 'left', nowMs: 12000).display(), '—');
  });
  testWidgets(
      'Live nav uses actual map container fallback and never illustrative map',
      (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    final g = FakeGateway();
    g.state['demo'] = false;
    g.state['navigation'] = {
      'canEmbed': false,
      'reason': '需要车机系统嵌入授权',
      'package': 'com.autonavi.amapauto',
      'enabled': true
    };
    final c = LauncherController(g);
    await c.initialize();
    await t.pumpWidget(LauncherApp(controller: c));
    await t.pumpAndSettle();
    expect(find.byType(EmbeddedNavigationCard), findsOneWidget);
    expect(find.text('600 米后右转'), findsNothing);
    await t.tap(find.text('全屏打开导航'));
    await t.pumpAndSettle();
    expect(g.commands.last['action'], 'launch-navigation');
    c.openSettings();
    c.tab('sources');
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('media-source')), findsOneWidget);
    expect(find.byKey(const ValueKey('navigation-source')), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    c.dispose();
    await g.dispose();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  testWidgets(
      'Settings retains desktop map state and preview does not start another map',
      (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    final g = FakeGateway();
    g.state['navigation'] = {
      'canEmbed': false,
      'package': 'com.autonavi.amapauto',
      'reason': '未授权'
    };
    final c = LauncherController(g);
    await c.initialize();
    await t.pumpWidget(LauncherApp(controller: c));
    await t.pumpAndSettle();
    final original = t.state(find.byType(EmbeddedNavigationCard));
    c.openSettings();
    await t.pumpAndSettle();
    expect(find.byType(EmbeddedContentPolicy), findsOneWidget);
    expect(
        find
            .byType(EmbeddedNavigationCard, skipOffstage: false)
            .evaluate()
            .any((e) => e is StatefulElement && identical(e.state, original)),
        true);
    c.home();
    await t.pumpAndSettle();
    expect(identical(t.state(find.byType(EmbeddedNavigationCard)), original),
        true);
    await t.pumpWidget(const SizedBox.shrink());
    c.dispose();
    await g.dispose();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  testWidgets('Fresh vehicle readings appear at correct tire corners',
      (t) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await t.pumpWidget(MaterialApp(
        theme: launcherTheme(SurfaceStyle.from(const Appearance(), true)),
        home: Scaffold(
            body: SizedBox(
                width: 700,
                height: 400,
                child: TireDiagram(native: {
                  'vehicle': {
                    'connected': true,
                    'fields': {
                      'pressureFrontLeft': {
                        'valid': true,
                        'value': 241,
                        'updatedAtMs': now
                      },
                      'pressureFrontRight': {
                        'valid': true,
                        'value': 242,
                        'updatedAtMs': now
                      },
                      'pressureRearLeft': {
                        'valid': true,
                        'value': 243,
                        'updatedAtMs': now
                      },
                      'pressureRearRight': {
                        'valid': true,
                        'value': 244,
                        'updatedAtMs': now
                      }
                    }
                  }
                })))));
    await t.pumpAndSettle();
    for (int v = 241; v <= 244; v++) expect(find.text('$v.0'), findsOneWidget);
    expect(t.getCenter(find.text('241.0')).dx,
        lessThan(t.getCenter(find.text('242.0')).dx));
    expect(t.getCenter(find.text('241.0')).dy,
        lessThan(t.getCenter(find.text('243.0')).dy));
    expect(t.takeException(), null);
  });
}
