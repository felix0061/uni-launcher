import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  // Flutter can reinstall the app before invoking the driver, clearing the
  // listener grant. Establish test-only prerequisites after that reinstall.
  final serial = Platform.environment['UNI_EMULATOR_SERIAL'] ?? 'emulator-5580';
  if (!RegExp(r'^emulator-\d+$').hasMatch(serial))
    throw StateError('Emulator required');
  Future<String> adb(List<String> args) async {
    final result = await Process.run('adb', ['-s', serial, ...args]);
    if (result.exitCode != 0)
      throw StateError('Emulator setup failed: ${result.stderr}');
    return '${result.stdout}'.trim();
  }

  if (await adb(['shell', 'getprop', 'ro.kernel.qemu']) != '1')
    throw StateError('Refusing to test a real vehicle');
  if (!(await adb(['shell', 'pm', 'path', 'ecarx.xsf.mediacenter']))
      .startsWith('package:'))
    throw StateError('Build the synthetic media fixture first');
  await adb([
    'shell',
    'cmd',
    'notification',
    'allow_listener',
    'xyz.i4o.uni.launcher/xyz.i4o.uni.launcher.integration.MediaAccessService'
  ]);
  await adb(['shell', 'am', 'force-stop', 'ecarx.xsf.mediacenter']);
  await adb(
      ['shell', 'am', 'start', '-n', 'ecarx.xsf.mediacenter/.FixtureActivity']);
  await adb(
      ['shell', 'am', 'start', '-n', 'xyz.i4o.uni.launcher/.MainActivity']);
  final out = Directory('verification')..createSync(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await File('${out.path}/$name.png').writeAsBytes(bytes);
      return true;
    },
    responseDataCallback: (data) async {
      final report = Map<String, dynamic>.from(data ?? {});
      final screenshots = report.remove('screenshots') as List? ?? [];
      report['screenshots'] =
          screenshots.map((shot) => '${shot['screenshotName']}.png').toList();
      await File('${out.path}/emulator-report.json').writeAsString(
          '${const JsonEncoder.withIndent('  ').convert(report)}\n');
    },
    writeResponseOnFailure: true,
  );
}
