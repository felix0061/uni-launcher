import 'dart:async';
import 'dart:convert';
import 'package:flutter_driver/flutter_driver.dart';
import 'dart:io';
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
  final out = Directory('verification/memory')..createSync(recursive: true);
  final driver = await FlutterDriver.connect();
  var running = true, sent = false;
  Future<void> poll() async {
    while (running) {
      try {
        final response = await driver.serviceClient.callServiceExtension(
            'ext.uni.lifecyclePressure',
            isolateId: driver.appIsolate.id);
        if (!sent && response.json!['waiting'] == true) {
          sent = true;
          await adb([
            'shell',
            'am',
            'send-trim-memory',
            'xyz.i4o.uni.launcher',
            'RUNNING_LOW'
          ]);
          await driver.serviceClient.callServiceExtension(
              'ext.uni.lifecyclePressure',
              isolateId: driver.appIsolate.id,
              args: {'release': 'true'});
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  final polling = poll();
  try {
    await integrationDriver(
        driver: driver,
        responseDataCallback: (data) async {
          await File('${out.path}/engine-lifecycle.json').writeAsString(
              '${const JsonEncoder.withIndent('  ').convert(data)}\n');
        },
        writeResponseOnFailure: true);
  } finally {
    running = false;
    await polling;
  }
}
