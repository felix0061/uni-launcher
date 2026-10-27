import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uni_launcher/controller/launcher_controller.dart';
import 'package:uni_launcher/model/appearance.dart';
import 'package:uni_launcher/model/card_layout.dart';
import 'package:uni_launcher/platform/audio_spectrum.dart';
import 'package:uni_launcher/platform/native_gateway.dart';
import 'package:uni_launcher/theme/launcher_theme.dart';
import 'package:uni_launcher/widgets/card_content.dart';
import 'package:uni_launcher/widgets/glass_surface.dart';
import '../test/fake_gateway.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'real Android output spectrum with permission and visibility gates',
      (t) async {
    final gateway = AndroidGateway();
    await gateway.action('global-dock', enabled: false);
    final native = await gateway.bootstrap();
    expect('${native['device']}'.contains('IP753'), false);
    final service = AudioSpectrumService.shared;
    var phase = 'starting';
    Completer<void>? gate;
    developer.registerExtension('ext.uni.spectrumProbe', (_, params) async {
      if (params['release'] == phase && gate?.isCompleted == false)
        gate!.complete();
      return developer.ServiceExtensionResponse.result(jsonEncode(
          {'phase': phase, 'waiting': gate != null && !gate!.isCompleted}));
    });
    Future<void> checkpoint(String name) async {
      phase = name;
      gate = Completer<void>();
      await gate!.future.timeout(const Duration(seconds: 20));
      gate = null;
    }

    await service.refreshStatus();
    expect(service.granted, false,
        reason:
            'Host must revoke RECORD_AUDIO before launching this emulator-only test');
    final fake = FakeGateway()..state['demo'] = false;
    fake.state['media'] = {
      'available': true,
      'playing': true,
      'source': 'com.test.player',
      'title': '真实音频 · 测试信号',
      'artist': 'Android 输出混音',
      'collection': '权限与采样验证',
      'lyricLine': '频谱来自实际音频输出',
      'canToggle': true
    };
    final controller = LauncherController(fake);
    await controller.initialize();
    final visible = ValueNotifier(true);
    Future<void> show(int w, int h, {bool panel = false}) async {
      final style = SurfaceStyle.from(
          const Appearance(themeStyle: 'blueGlass', mode: 'dark'), true);
      await t.pumpWidget(MaterialApp(
          theme: launcherTheme(style),
          home: Scaffold(
              backgroundColor: const Color(0xff0c1526),
              body: Center(
                  child: ValueListenableBuilder<bool>(
                      valueListenable: visible,
                      builder: (_, enabled, __) => TickerMode(
                          enabled: enabled,
                          child: SizedBox(
                              width: panel ? 1050 : w * 125.0,
                              height: panel ? 600 : h * 100.0,
                              child: GlassSurface(
                                  padding: EdgeInsets.zero,
                                  child: panel
                                      ? Padding(
                                          padding: const EdgeInsets.all(28),
                                          child: MediaPanel(
                                              controller: controller))
                                      : CardContent(
                                          card: LauncherCard('spectrum-music',
                                              'music', '音乐', 0, 0, w, h, 0),
                                          controller: controller)))))))));
      await t.pumpAndSettle();
    }

    await show(4, 3);
    expect(find.byKey(const ValueKey('enable-audio-spectrum')), findsOneWidget);
    await checkpoint('grant-and-tone');
    await service.refreshStatus();
    expect(service.granted, true);
    // Restart demand after the host grants permission outside Android's dialog.
    visible.value = false;
    await t.pump();
    await t.pump();
    visible.value = true;
    await t.pump();
    await t.pump();
    for (var i = 0;
        i < 50 && (!service.available || !service.levels.any((v) => v > .05));
        i++) {
      await t.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    print(
        'SPECTRUM native: ${await service.methods.invokeMethod('status')} levels=${service.levels} sequence=${service.sequence}');
    expect(service.available, true, reason: service.status);
    expect(service.levels.length, 24);
    expect(service.levels.any((v) => v > .05), true,
        reason:
            'A real audible tone must produce nonzero FFT, not a decorative animation');
    final maxLevel = service.levels.reduce((a, b) => a > b ? a : b);
    await binding.convertFlutterSurfaceToImage();
    await t.pump();
    for (final size in [(4, 2), (4, 3), (4, 4), (8, 6)]) {
      await show(size.$1, size.$2);
      expect(t.takeException(), isNull);
      await binding.takeScreenshot('spectrum-music-${size.$1}x${size.$2}');
    }
    await show(4, 3, panel: true);
    await binding.takeScreenshot('spectrum-music-panel');
    final before = service.sequence;
    await Future<void>.delayed(const Duration(seconds: 2));
    await t.pump();
    final framesInTwoSeconds = service.sequence - before;
    expect(framesInTwoSeconds, inInclusiveRange(1, 22));
    visible.value = false;
    await t.pump();
    await t.pump();
    expect(service.activeConsumers, 0);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final stoppedSequence = service.sequence;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(service.sequence, stoppedSequence);
    final stopped =
        await service.methods.invokeMapMethod<String, dynamic>('status');
    expect(stopped!['running'], false);
    await checkpoint('stop-tone');
    await t.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await fake.dispose();
    visible.dispose();
    binding.reportData = {
      ...?binding.reportData,
      'permissionMissingVerified': true,
      'permissionGrantedVerified': true,
      'source': 'Android Visualizer output-mix',
      'actualToneDetected': true,
      'maxLevel': maxLevel,
      'bands': 24,
      'framesInTwoSeconds': framesInTwoSeconds,
      'hiddenCaptureStopped': true,
      'cardLayouts': ['4x2', '4x3', '4x4', '8x6'],
      'noLayoutErrors': true
    };
  });
}
