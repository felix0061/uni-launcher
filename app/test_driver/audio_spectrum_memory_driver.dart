import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  const serial = 'emulator-5580', pkg = 'xyz.i4o.uni.launcher';
  Future<String> adb(List<String> args) async {
    final r = await Process.run('adb', ['-s', serial, ...args])
        .timeout(const Duration(seconds: 15));
    if (r.exitCode != 0) throw StateError('${r.stderr}');
    return '${r.stdout}'.trim();
  }

  if (await adb(['shell', 'getprop', 'ro.kernel.qemu']) != '1')
    throw StateError('Emulator required');
  final out = Directory('verification/audio-spectrum/memory')
    ..createSync(recursive: true);
  final driver = await FlutterDriver.connect();
  final vm = driver.serviceClient;
  final started = DateTime.now();
  final seen = <String>{}, rows = <Map<String, dynamic>>[];
  var running = true;
  Future<void> poll() async {
    while (running) {
      try {
        final probe = await vm.callServiceExtension('ext.uni.spectrumMemory',
            isolateId: driver.appIsolate.id);
        final metadata = probe.json!, phase = '${metadata['phase']}';
        if (metadata['waiting'] == true && seen.add(phase)) {
          if (phase == 'prepare-tone') {
            await adb([
              'shell',
              'pm',
              'grant',
              pkg,
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
            await adb(['shell', 'am', 'start', '-n', '$pkg/.MainActivity']);
          } else {
            final allocation =
                await vm.getAllocationProfile(driver.appIsolate.id!, gc: true);
            final dartMemory = await vm.getMemoryUsage(driver.appIsolate.id!);
            final raw = await adb(['shell', 'dumpsys', 'meminfo', pkg]);
            final audio =
                await adb(['shell', 'dumpsys', 'meminfo', 'audioserver']);
            int? pss(String text) =>
                int.tryParse(RegExp(r'^\s*TOTAL\s+(\d+)', multiLine: true)
                        .firstMatch(text)?[1] ??
                    '');
            int? heap(String label) =>
                int.tryParse(RegExp('^\\s*$label\\s+(\\d+)', multiLine: true)
                        .firstMatch(raw)?[1] ??
                    '');
            final row = <String, dynamic>{
              'phase': phase,
              'elapsedSec':
                  DateTime.now().difference(started).inMilliseconds / 1000,
              'appPssKiB': pss(raw),
              'audioServerPssKiB': pss(audio),
              'nativeHeapPssKiB': heap('Native Heap'),
              'javaHeapPssKiB': heap('Dalvik Heap'),
              'dartMemory': dartMemory.toJson(),
              'metadata': metadata,
              'retainedSpectrumClasses': [
                for (final cls in allocation.members ?? [])
                  if (RegExp(
                          r'^(_AudioSpectrumState|AudioSpectrumService|AudioSpectrumPainter)$')
                      .hasMatch(cls.classRef?.name ?? ''))
                    {
                      'name': cls.classRef?.name,
                      'instances': cls.instancesCurrent,
                      'bytes': cls.bytesCurrent
                    }
              ]
            };
            rows.add(row);
            await File('${out.path}/$phase-mem.txt').writeAsString(
                '${raw.split('\n').map((line) => line.trimRight()).join('\n')}\n');
            await File('${out.path}/checkpoints.json').writeAsString(
                '${const JsonEncoder.withIndent('  ').convert(rows)}\n');
            print(
                'SPECTRUM MEMORY $phase: app=${row['appPssKiB']} KiB native=${row['nativeHeapPssKiB']} KiB dart=${dartMemory.heapUsage} bytes');
          }
          await vm.callServiceExtension('ext.uni.spectrumMemory',
              isolateId: driver.appIsolate.id, args: {'release': phase});
        }
      } catch (error) {
        if (running && !'$error'.contains('Method not found'))
          print('Spectrum memory probe: $error');
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  final polling = poll();
  try {
    await integrationDriver(
        driver: driver,
        responseDataCallback: (data) async {
          await File('${out.path}/test-report.json').writeAsString(
              '${const JsonEncoder.withIndent('  ').convert(data)}\n');
        },
        writeResponseOnFailure: true);
  } finally {
    running = false;
    await polling;
    await adb(['shell', 'am', 'force-stop', 'xyz.i4o.uni.spectrumfixture']);
  }
}
