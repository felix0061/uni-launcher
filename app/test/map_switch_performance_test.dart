import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_launcher/controller/launcher_controller.dart';
import 'package:uni_launcher/model/appearance.dart';
import 'package:uni_launcher/theme/launcher_theme.dart';
import 'package:uni_launcher/widgets/embedded_navigation.dart';
import 'fake_gateway.dart';
import 'package:uni_launcher/widgets/page_transition.dart';

void main() {
  testWidgets(
      'map visibility waits for settled motion and survives rapid reversal',
      (t) async {
    final messenger = t.binding.defaultBinaryMessenger;
    final created = <int>[], disposed = <int>[];
    final visibility = <bool>[];
    final gateway = FakeGateway(), controller = LauncherController(gateway);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,
        (call) async {
      final args = call.arguments;
      if (call.method == 'create') {
        final id = (args as Map)['id'] as int;
        created.add(id);
        messenger.setMockMethodCallHandler(
            MethodChannel('xyz.i4o.uni.launcher/map/$id'), (call) async {
          if (call.method == 'visible') visibility.add(call.arguments as bool);
          return call.method == 'status'
              ? {'phase': 'ready', 'ready': true}
              : null;
        });
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
    Future<void> show(int page,
        {String effect = 'slide', bool settings = false}) async {
      controller.settings = settings;
      await t.pumpWidget(MaterialApp(
          theme: launcherTheme(SurfaceStyle.from(const Appearance(), false)),
          home: Scaffold(
              body: DesktopPageStack(page: page, effect: effect, children: [
            EmbeddedContentPolicy(
                enabled: true,
                visible: page == 0,
                child: EmbeddedNavigationCard(
                    controller: controller,
                    navigation: const {
                      'package': 'test.map',
                      'label': '地图',
                      'canEmbed': true
                    })),
            const Text('other page'),
          ]))));
    }

    await show(0);
    await t.pumpAndSettle();
    expect(created, hasLength(1));
    expect(visibility.last, true);
    final id = created.single;
    await show(1);
    await t.pumpAndSettle();
    expect(visibility.last, false);
    visibility.clear();
    await show(0);
    await t.pump(const Duration(milliseconds: 60));
    expect(visibility, isNot(contains(true)),
        reason: 'native must stay hidden during motion');
    expect(find.byKey(const ValueKey('map-restoring-preview')), findsOneWidget);
    await show(1); // Cancel before the map settles.
    await t.pumpAndSettle();
    expect(visibility, isNot(contains(true)));
    await show(0);
    await t.pump(const Duration(milliseconds: 60));
    expect(visibility, isNot(contains(true)));
    await t.pumpAndSettle();
    expect(visibility.where((v) => v), hasLength(1));
    await messenger.handlePlatformMessage(
        'xyz.i4o.uni.launcher/map/$id',
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('status', {
          'phase': 'loading',
          'ready': false,
        })),
        (_) {});
    await t.pump();
    expect(find.byKey(const ValueKey('map-restoring-preview')), findsOneWidget,
        reason: 'settled motion alone must not remove the preview');
    final cardElement = t.element(find.byType(EmbeddedNavigationCard));
    for (int sample = 0; sample < 20; sample++) {
      await messenger.handlePlatformMessage(
          'xyz.i4o.uni.launcher/map/$id',
          const StandardMethodCodec()
              .encodeMethodCall(const MethodCall('status', {
            'phase': 'loading',
            'ready': false,
          })),
          (_) {});
      expect(cardElement.dirty, false,
          reason: 'identical native status must not schedule a card rebuild');
    }
    await show(0, settings: true);
    await t.pump(const Duration(milliseconds: 500));
    expect(visibility.last, false);
    await show(0, effect: 'none');
    await t.pump(const Duration(milliseconds: 500));
    expect(visibility.last, true);
    expect(created, [id]);
    expect(disposed, isEmpty);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
