import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
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
