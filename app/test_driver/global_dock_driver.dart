import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final serial = Platform.environment['UNI_EMULATOR_SERIAL'] ?? 'emulator-5580';
  if (!RegExp(r'^emulator-\d+$').hasMatch(serial))
    throw StateError('Emulator required');
  Future<String> adb(List<String> a) async {
    final r = await Process.run('adb', ['-s', serial, ...a]);
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
  final policyBefore =
      await adb(['shell', 'settings', 'get', 'global', 'policy_control']);
  final out = Directory('verification/global-dock')
    ..createSync(recursive: true);
  await integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        await File('${out.path}/$name.png').writeAsBytes(bytes);
        return true;
      },
      responseDataCallback: (data) async {
        final r = Map<String, dynamic>.from(data ?? {})..remove('screenshots');
        final policyAfter =
            await adb(['shell', 'settings', 'get', 'global', 'policy_control']);
        if (policyBefore != policyAfter)
          throw StateError('System navigation policy was not restored');
        r['nativePolicyRestored'] = true;
        await File('${out.path}/policy-restored.json')
            .writeAsString(jsonEncode({'restored': true}));
        await File('${out.path}/integration-report.json').writeAsString(
            '${const JsonEncoder.withIndent('  ').convert(r)}\n');
      },
      writeResponseOnFailure: true);
}
