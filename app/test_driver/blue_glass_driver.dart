import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final serial = Platform.environment['UNI_EMULATOR_SERIAL'] ?? 'emulator-5580';
  if (!RegExp(r'^emulator-\d+$').hasMatch(serial))
    throw StateError('Emulator required');
  final device = await Process.run(
      'adb', ['-s', serial, 'shell', 'getprop', 'ro.kernel.qemu']);
  if ('${device.stdout}'.trim() != '1')
    throw StateError('Refusing real vehicle');
  final out = Directory('verification/blue-glass')..createSync(recursive: true);
  await integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        if (!RegExp(r'^blue-glass-[a-z0-9-]+$').hasMatch(name)) return false;
        await File('${out.path}/$name.png').writeAsBytes(bytes);
        return true;
      },
      responseDataCallback: (data) async {
        final report = Map<String, dynamic>.from(data ?? {});
        final screenshots = report.remove('screenshots') as List? ?? [];
        report['screenshots'] =
            screenshots.map((e) => '${e['screenshotName']}.png').toList();
        await File('${out.path}/emulator-report.json').writeAsString(
            '${const JsonEncoder.withIndent('  ').convert(report)}\n');
      },
      writeResponseOnFailure: true);
}
