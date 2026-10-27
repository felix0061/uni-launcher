import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_launcher/model/appearance.dart';
import 'package:uni_launcher/platform/audio_spectrum.dart';
import 'package:uni_launcher/theme/launcher_theme.dart';
import 'package:uni_launcher/widgets/audio_spectrum.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('test/spectrum-control');
  const events = EventChannel('test/spectrum-events');
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      if (call.method == 'status') {
        return {
          'granted': false,
          'available': false,
          'status': 'permission-required'
        };
      }
      return null;
    });
    messenger.setMockMethodCallHandler(MethodChannel(events.name),
        (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(MethodChannel(events.name), null);
  });

  testWidgets(
      'multiple visible consumers share capture and final release stops it',
      (t) async {
    final service = AudioSpectrumService(methods: methods, events: events);
    final card = Object(), dialog = Object();
    service.setDemand(card, true);
    service.setDemand(dialog, true);
    await t.pump();
    expect(calls.where((c) => c.method == 'listen').length, 1);
    expect(calls.where((c) => c.method == 'active').map((c) => c.arguments),
        [true]);
    service.setDemand(card, false);
    await t.pump();
    expect(service.activeConsumers, 1);
    service.setDemand(dialog, false);
    await t.pump();
    expect(service.activeConsumers, 0);
    expect(calls.where((c) => c.method == 'active').map((c) => c.arguments),
        [true, false]);
    expect(calls.where((c) => c.method == 'cancel').length, 1);
    expect(service.available, false);
    service.dispose();
    await t.pump();
  });

  test('frequency packets are bounded and invalid samples never reach painter',
      () {
    final service = AudioSpectrumService(methods: methods, events: events);
    service.accept({
      'granted': true,
      'available': true,
      'status': 'listening',
      'levels': [
        -1,
        2,
        double.nan,
        double.infinity,
        'bad',
        ...List.filled(30, .4)
      ]
    });
    expect(service.levels.length, 24);
    expect(service.levels.take(6), [0, 1, 0, 0, 0, .4]);
    service
        .accept({'granted': true, 'available': false, 'status': 'unavailable'});
    expect(service.levels, isEmpty);
    service.dispose();
  });

  testWidgets(
      'FFT packets repaint the small canvas without rebuilding music widgets',
      (t) async {
    final service = AudioSpectrumService(methods: methods, events: events);
    await t.pumpWidget(MaterialApp(
        theme: launcherTheme(SurfaceStyle.from(const Appearance(), true)),
        home: Scaffold(
            body: SizedBox(
                width: 300,
                child: AudioSpectrum(playing: true, service: service)))));
    await t.pump();
    service.accept({
      'granted': true,
      'available': true,
      'status': 'listening',
      'levels': List.filled(24, .2)
    });
    await t.pump();
    var widgetBuilds = 0;
    final before = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      before?.call(element, builtOnce);
      if (element.widget is AudioSpectrum) widgetBuilds++;
    };
    try {
      for (var frame = 0; frame < 10; frame++) {
        service.accept({
          'granted': true,
          'available': true,
          'status': 'listening',
          'levels': List.filled(24, frame / 10)
        });
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(widgetBuilds, 0);
      expect(t.binding.transientCallbackCount, 0,
          reason: 'No animation ticker is required for actual FFT samples');
    } finally {
      debugOnRebuildDirtyWidget = before;
      await t.pumpWidget(const SizedBox.shrink());
      service.dispose();
      await t.pump();
    }
  });

  testWidgets(
      'offscreen paused and disposed widgets release demand; permission is explicit',
      (t) async {
    final service = AudioSpectrumService(methods: methods, events: events);
    Future<void> show({bool visible = true, bool playing = true}) async {
      await t.pumpWidget(MaterialApp(
          theme: launcherTheme(SurfaceStyle.from(const Appearance(), true)),
          home: Scaffold(
              body: TickerMode(
                  enabled: visible,
                  child: SizedBox(
                      width: 300,
                      child: AudioSpectrum(
                          playing: playing, service: service))))));
      await t.pump();
    }

    await show();
    expect(service.activeConsumers, 1);
    expect(find.byKey(const ValueKey('enable-audio-spectrum')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('enable-audio-spectrum')));
    await t.pump();
    expect(calls.where((c) => c.method == 'permission').length, 1);
    await show(visible: false);
    expect(service.activeConsumers, 0);
    await show(playing: false);
    expect(service.activeConsumers, 0);
    await show();
    expect(service.activeConsumers, 1);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(service.activeConsumers, 0);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(service.activeConsumers, 1);
    await t.pumpWidget(const SizedBox.shrink());
    expect(service.activeConsumers, 0);
    service.dispose();
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
