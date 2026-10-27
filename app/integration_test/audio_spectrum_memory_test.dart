import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uni_launcher/model/appearance.dart';
import 'package:uni_launcher/platform/audio_spectrum.dart';
import 'package:uni_launcher/platform/native_gateway.dart';
import 'package:uni_launcher/theme/launcher_theme.dart';
import 'package:uni_launcher/widgets/audio_spectrum.dart';

/// One fixed canvas and a separate continuous AudioTrack tone in every phase.
/// Do not compare these profile numbers to the full release desktop's PSS.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('FFT memory under fixed audio, recreation and sustained capture',
      (t) async {
    await AndroidGateway().action('global-dock', enabled: false);
    final service = AudioSpectrumService.shared;
    final setting = ValueNotifier((false, 0));
    var phase = 'starting';
    var metadata = <String, dynamic>{};
    Completer<void>? gate;
    developer.registerExtension('ext.uni.spectrumMemory', (_, params) async {
      if (params['release'] == phase && gate?.isCompleted == false)
        gate!.complete();
      return developer.ServiceExtensionResponse.result(jsonEncode({
        'phase': phase,
        'waiting': gate != null && !gate!.isCompleted,
        ...metadata
      }));
    });
    Future<void> waitMs(int ms) async {
      for (var elapsed = 0; elapsed < ms; elapsed += 100) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await t.pump();
      }
    }

    Future<void> checkpoint(String name) async {
      metadata = {
        'native':
            await service.methods.invokeMapMethod<String, dynamic>('status'),
        'dartOwners': service.activeConsumers,
        'retainedBands': service.levels.length,
      };
      phase = name;
      gate = Completer<void>();
      await gate!.future.timeout(const Duration(seconds: 30));
      gate = null;
    }

    Future<void> setCapture(bool enabled, int generation) async {
      setting.value = (enabled, generation);
      await t.pump();
      await t.pump();
      await waitMs(300);
      expect(service.activeConsumers, enabled ? 1 : 0);
      final native =
          await service.methods.invokeMapMethod<String, dynamic>('status');
      expect(native!['running'], enabled);
    }

    await t.pumpWidget(MaterialApp(
        theme: launcherTheme(
            SurfaceStyle.from(const Appearance(mode: 'dark'), true)),
        home: Scaffold(
            body: Center(
                child: ValueListenableBuilder<(bool, int)>(
                    valueListenable: setting,
                    builder: (_, state, __) => SizedBox(
                        width: 400,
                        height: 60,
                        child: AudioSpectrum(
                            key: ValueKey(state.$2),
                            playing: state.$1,
                            service: service)))))));
    await t.pumpAndSettle();
    await checkpoint('prepare-tone');
    await service.refreshStatus();
    expect(service.granted, true);
    await waitMs(3000);
    await checkpoint('cold-off');
    await setCapture(true, 0);
    await waitMs(5000);
    expect(service.levels.any((v) => v > .05), true,
        reason: 'Real tone required');
    await checkpoint('warm-on');
    await setCapture(false, 0);
    await waitMs(3000);
    await checkpoint('warm-off');
    for (var cycle = 1; cycle <= 30; cycle++) {
      await setCapture(true, cycle);
      await setCapture(false, cycle);
      if (cycle % 10 == 0) await checkpoint('off-after-$cycle-cycles');
    }
    await setCapture(true, 31);
    var previousSequence = service.sequence;
    for (var elapsed = 30; elapsed <= 180; elapsed += 30) {
      await waitMs(30000);
      expect(service.available, true);
      expect(service.sequence, greaterThan(previousSequence));
      previousSequence = service.sequence;
      expect(service.levels.any((v) => v > .05), true,
          reason: 'Tone must remain active throughout the soak');
      await checkpoint('active-$elapsed-seconds');
    }
    await setCapture(false, 31);
    await waitMs(3000);
    final sequence = service.sequence;
    await waitMs(1000);
    expect(service.sequence, sequence);
    expect(service.levels, isEmpty);
    await checkpoint('final-off');
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
    expect(service.activeConsumers, 0);
    await waitMs(2000);
    await checkpoint('unmounted');
    setting.dispose();
    binding.reportData = {
      'cycles': 30,
      'continuousCaptureSeconds': 180,
      'actualToneDetected': true,
      'stoppedSequenceStable': true,
      'noOwnersAfterUnmount': true,
      'scope':
          'API28 x86_64 profile, one FFT canvas, constant external AudioTrack; VM GC before memory checkpoints, not vehicle or full launcher'
    };
  }, timeout: const Timeout(Duration(minutes: 8)));
}
