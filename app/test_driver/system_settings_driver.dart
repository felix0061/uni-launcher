import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final out = Directory('verification/system-settings')
    ..createSync(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      if (name != 'system-settings-android9') return false;
      await File('${out.path}/$name.png').writeAsBytes(bytes);
      return true;
    },
    responseDataCallback: (data) async {
      final report = Map<String, dynamic>.from(data ?? {})
        ..remove('screenshots');
      await File('${out.path}/emulator-report.json').writeAsString(
          '${const JsonEncoder.withIndent('  ').convert(report)}\n');
    },
    writeResponseOnFailure: true,
  );
}
