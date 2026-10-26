import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_launcher/controller/launcher_controller.dart';
import 'package:uni_launcher/model/appearance.dart';
import 'package:uni_launcher/theme/launcher_theme.dart';
import 'package:uni_launcher/widgets/embedded_navigation.dart';
import 'fake_gateway.dart';

void main() {
  testWidgets('map preview arrival and restoration never recreate native view',
      (t) async {
    final messenger = t.binding.defaultBinaryMessenger;
    final created = <int>[], disposed = <int>[];
    final gateway = FakeGateway(), controller = LauncherController(gateway);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,
        (call) async {
      final args = call.arguments;
      if (call.method == 'create') {
        final id = (args as Map)['id'] as int;
        created.add(id);
        messenger.setMockMethodCallHandler(
            MethodChannel('xyz.i4o.uni.launcher/map/$id'),
            (call) async => call.method == 'status'
                ? {'phase': 'ready', 'ready': true}
                : null);
      } else if (call.method == 'dispose') {
        disposed.add((args as Map)['id'] as int);
      }
      return null;
    });
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final id in created) {
        messenger.setMockMethodCallHandler(
            MethodChannel('xyz.i4o.uni.launcher/map/$id'), null);
      }
      controller.dispose();
      await gateway.dispose();
    });
    await t.pumpWidget(MaterialApp(
        theme: launcherTheme(SurfaceStyle.from(const Appearance(), false)),
        home: Scaffold(
            body: EmbeddedNavigationCard(
                controller: controller,
                navigation: const {
              'package': 'test.map',
              'label': '地图',
              'canEmbed': true
            }))));
    await t.pumpAndSettle();
    expect(created, hasLength(1));
    final id = created.single;
    for (final ready in [true, false, true, false, true]) {
      await messenger.handlePlatformMessage(
          'xyz.i4o.uni.launcher/map/$id',
          const StandardMethodCodec().encodeMethodCall(MethodCall('status', {
            'phase': ready ? 'ready' : 'loading',
            'ready': ready,
            'previewTextureId': 7,
          })),
          (_) {});
      await t.pumpAndSettle();
      expect(created, [id],
          reason: 'preview layers must not replace the map surface');
      expect(disposed, isEmpty);
    }
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
