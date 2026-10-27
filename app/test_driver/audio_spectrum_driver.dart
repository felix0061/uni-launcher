import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  const serial = 'emulator-5580';
  Future<String> adb(List<String> args) async {
    final r = await Process.run('adb', ['-s', serial, ...args]);
    if (r.exitCode != 0) throw StateError('${r.stderr}');
    return '${r.stdout}'.trim();
  }

  if (await adb(['shell', 'getprop', 'ro.kernel.qemu']) != '1')
    throw StateError('Emulator required');
  final out = Directory(
      Platform.environment['UNI_SPECTRUM_OUT'] ?? 'verification/audio-spectrum')
    ..createSync(recursive: true);
  final driver = await FlutterDriver.connect();
  final vm = driver.serviceClient;
  var running = true;
  final seen = <String>{};
  Future<void> poll() async {
    while (running) {
      try {
        final response = await vm.callServiceExtension('ext.uni.spectrumProbe',
            isolateId: driver.appIsolate.id);
        final meta = response.json!;
        final phase = '${meta['phase']}';
        if (meta['waiting'] == true && seen.add(phase)) {
          if (phase == 'grant-and-tone') {
            await adb([
              'shell',
              'pm',
              'grant',
              'xyz.i4o.uni.launcher',
              'android.permission.RECORD_AUDIO'
            ]);
            await adb([
              'shell',
              'am',
              'start',
              '-n',
              'xyz.i4o.uni.spectrumfixture/.ToneActivity'
            ]);
            await Future<void>.delayed(const Duration(milliseconds: 800));
            await adb([
              'shell',
              'am',
              'start',
              '-n',
              'xyz.i4o.uni.launcher/.MainActivity'
            ]);
          } else if (phase == 'stop-tone') {
            await adb(
                ['shell', 'am', 'force-stop', 'xyz.i4o.uni.spectrumfixture']);
          }
          await vm.callServiceExtension('ext.uni.spectrumProbe',
              isolateId: driver.appIsolate.id, args: {'release': phase});
        }
      } catch (error) {
        if (running && !'$error'.contains('Method not found'))
          print('Spectrum probe: $error');
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  final polling = poll();
  try {
    await integrationDriver(
        driver: driver,
        onScreenshot: (name, bytes, [args]) async {
          if (!RegExp(r'^spectrum-music-[a-z0-9-]+$').hasMatch(name))
            return false;
          await File('${out.path}/$name.png').writeAsBytes(bytes);
          return true;
        },
        responseDataCallback: (data) async {
          final report = Map<String, dynamic>.from(data ?? {})
            ..remove('screenshots');
          await File('${out.path}/emulator-report.json').writeAsString(
              '${const JsonEncoder.withIndent('  ').convert(report)}\n');
        },
        writeResponseOnFailure: true);
  } finally {
    running = false;
    await polling;
    await adb(['shell', 'am', 'force-stop', 'xyz.i4o.uni.spectrumfixture']);
  }
}
