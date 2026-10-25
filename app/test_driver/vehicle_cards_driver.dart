import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

/// Screenshot sink only. Does not call adb, grant permissions, start media,
/// bootstrap the launcher, or modify saved layouts/preferences.
Future<void> main() async {
  final out = Directory('verification/vehicle-cards')
    ..createSync(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      if (!RegExp(r'^vehicle-cards-[a-z0-9-]+$').hasMatch(name)) return false;
      await File('${out.path}/$name.png').writeAsBytes(bytes);
      return true;
    },
    responseDataCallback: (data) async {
      final report = Map<String, dynamic>.from(data ?? {})
        ..remove('screenshots');
      await File('${out.path}/gallery-report.json').writeAsString(
          '${const JsonEncoder.withIndent('  ').convert(report)}\n');
    },
    writeResponseOnFailure: true,
  );
}
