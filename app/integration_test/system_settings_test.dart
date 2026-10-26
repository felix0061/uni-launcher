import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uni_launcher/main.dart' as app;
import 'package:uni_launcher/launcher_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('device discovers and displays real system setting labels',
      (t) async {
    await app.main();
    await t.pumpAndSettle();
    final c = t.widget<LauncherApp>(find.byType(LauncherApp)).controller;
    await c.command('global-dock', enabled: false);
    c.openSettings();
    c.tab('system');
    await t.pumpAndSettle();
    final state = await c.gateway.bootstrap();
    final settings = Map<String, dynamic>.from(state['systemSettings'] as Map);
    final entries = settings['entries'] as List;
    expect(entries, isNotEmpty);
    expect(
        entries.every((e) =>
            e['label'] is String && (e['label'] as String).trim().isNotEmpty),
        isTrue);
    expect(entries.any((e) => e['package'] == 'com.android.settings'), isTrue);
    expect(entries.map((e) => e['id']).toSet().length, entries.length);
    final audio = settings['navigationAudio'] as Map;
    // Emulator cannot pretend it has an ECARX audio service.
    expect(audio['available'], isFalse);
    expect(find.byKey(const ValueKey('navigation-audio-unavailable')),
        findsOneWidget);
    expect(find.text('系统设置入口'), findsOneWidget);
    expect(t.takeException(), isNull);
    await binding.convertFlutterSurfaceToImage();
    await t.pumpAndSettle();
    await binding.takeScreenshot('system-settings-android9');
    binding.reportData = {
      ...?binding.reportData,
      'settingsEntryCount': entries.length,
      'labels': entries.map((e) => e['label']).toList(),
      'navigationAudioUnavailable': audio['available'] == false,
    };
  });
}
