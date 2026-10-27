import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  const serial = 'emulator-5580';
  final nativeOnly = Platform.environment['UNI_MEMORY_NATIVE_ONLY'] == '1';
  final out = Directory(Platform.environment['UNI_MEMORY_OUT'] ??
      'verification/memory-0.6.12${nativeOnly ? '/native-only' : ''}')
    ..createSync(recursive: true);
  Future<String> adb(List<String> args) async {
    final r = await Process.run(
        '/data/tools/linkco-android/sdk/platform-tools/adb',
        ['-s', serial, ...args]).timeout(const Duration(seconds: 20));
    if (r.exitCode != 0) throw StateError('${r.stderr}');
    return '${r.stdout}'.trim();
  }

  if (await adb(['shell', 'getprop', 'ro.kernel.qemu']) != '1')
    throw StateError('Emulator required');
  await adb([
    'shell',
    'appops',
    'set',
    'xyz.i4o.uni.launcher',
    'SYSTEM_ALERT_WINDOW',
    'allow'
  ]);
  await adb([
    'shell',
    'pm',
    'grant',
    'xyz.i4o.uni.launcher',
    'android.permission.WRITE_SECURE_SETTINGS'
  ]);
  final driver = await FlutterDriver.connect();
  final vm = driver.serviceClient;
  final rows = <Map<String, dynamic>>[];
  final started = DateTime.now();
  var running = true;
  final seen = <String>{};
  Future<void> poll() async {
    while (running) {
      try {
        final response = await vm.callServiceExtension('ext.uni.memoryProbe',
            isolateId: driver.appIsolate.id);
        final meta = response.json!;
        final phase = '${meta['phase']}';
        if (meta['waiting'] == true && seen.add(phase)) {
          final isolates = <Map<String, dynamic>>[];
          for (final isolate in (await vm.getVM()).isolates ?? []) {
            final entry = <String, dynamic>{
              'name': isolate.name,
              'id': isolate.id,
              'isolateGroupId': isolate.isolateGroupId
            };
            try {
              if (nativeOnly)
                throw StateError(
                    'Allocation profiling intentionally skipped for control run');
              final allocation =
                  await vm.getAllocationProfile(isolate.id!, gc: true);
              entry['gcSucceeded'] = true;
              entry['stateClasses'] = [
                for (final cls in allocation.members ?? [])
                  if (RegExp(
                          r'LauncherController|SnapshotImages|LyricsViewState|MediaProgressState|MediaArtworkState|EmbeddedNavigationCardState|HeaderState|GlobalPanelAppState|DesktopState')
                      .hasMatch(cls.classRef?.name ?? ''))
                    {
                      'name': cls.classRef?.name,
                      'instances': cls.instancesCurrent,
                      'bytes': cls.bytesCurrent
                    },
              ];
            } catch (error) {
              entry['allocationError'] = '$error';
              try {
                if (nativeOnly)
                  throw StateError('GC intentionally skipped for control run');
                await vm.callMethod('_collectAllGarbage',
                    isolateId: isolate.id!);
                entry['gcSucceeded'] = true;
              } catch (error) {
                entry['gcSucceeded'] = false;
                entry['gcError'] = '$error';
              }
            }
            entry['memory'] = (await vm.getMemoryUsage(isolate.id!)).toJson();
            isolates.add(entry);
          }
          final raw = await adb(
              ['shell', 'dumpsys', 'meminfo', 'xyz.i4o.uni.launcher']);
          await File('${out.path}/profile-$phase-mem.txt').writeAsString(
              '${raw.split('\n').map((line) => line.trimRight()).join('\n')}\n');
          final total =
              RegExp(r'^\s*TOTAL\s+(\d+)', multiLine: true).firstMatch(raw);
          final row = <String, dynamic>{
            'phase': phase,
            'elapsedSec':
                DateTime.now().difference(started).inMilliseconds / 1000,
            'pssKiB': total == null ? null : int.parse(total[1]!),
            'isolates': isolates,
            'metadata': meta
          };
          rows.add(row);
          await File('${out.path}/profile-checkpoints.json').writeAsString(
              '${const JsonEncoder.withIndent('  ').convert(rows)}\n');
          print(
              'MEMORY $phase: PSS=${row['pssKiB']} KiB, isolates=${isolates.length}');
          await vm.callServiceExtension('ext.uni.memoryProbe',
              isolateId: driver.appIsolate.id,
              args: {'release': phase, 'nativeOnly': '$nativeOnly'});
        }
      } catch (error) {
        if (running && !'$error'.contains('Method not found'))
          print('Memory probe: $error');
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  final polling = poll();
  await integrationDriver(
      driver: driver,
      responseDataCallback: (data) async {
        running = false;
        await polling;
        await File('${out.path}/profile-test-report.json').writeAsString(
            '${const JsonEncoder.withIndent('  ').convert(data)}\n');
      },
      writeResponseOnFailure: true);
}
