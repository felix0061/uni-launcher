import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_launcher/controller/launcher_controller.dart';
import 'package:uni_launcher/model/appearance.dart';
import 'package:uni_launcher/theme/launcher_theme.dart';
import 'package:uni_launcher/widgets/embedded_navigation.dart';
import 'fake_gateway.dart';
import 'package:uni_launcher/widgets/page_transition.dart';

final previewBytes = base64Decode(
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAACAAIDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDlqKKK+qPmz//Z');

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
    Future<void> show({bool moving = false}) async {
      await t.pumpWidget(MaterialApp(
          theme: launcherTheme(SurfaceStyle.from(const Appearance(), false)),
          home: Scaffold(
              body: DesktopMotionScope(
                  moving: moving,
                  child: EmbeddedNavigationCard(
                      controller: controller,
                      navigation: const {
                        'package': 'test.map',
                        'label': '地图',
                        'canEmbed': true
                      })))));
      await t.pump();
    }

    await show();
    await t.pumpAndSettle();
    expect(created, hasLength(1));
    final id = created.single;
    Future<void> status(bool ready, {int? revision = 1}) async {
      await messenger.handlePlatformMessage(
          'xyz.i4o.uni.launcher/map/$id',
          const StandardMethodCodec().encodeMethodCall(MethodCall('status', {
            'phase': ready ? 'ready' : 'loading',
            'ready': ready,
            if (revision != null) ...{
              'previewBytes': Uint8List.fromList(previewBytes),
              'previewRevision': revision,
            },
          })),
          (_) {});
      await t.pump();
      expect(created, [id]);
      expect(disposed, isEmpty);
    }

    await status(false);
    final first = t.widget<Image>(find.byType(Image)).image as MemoryImage;
    await t.runAsync(() => precacheImage(first, t.element(find.byType(Image))));
    await t.pump();
    expect(PaintingBinding.instance.imageCache.containsKey(first), true);
    for (final ready in [true, false, true, false]) {
      await status(ready);
      expect(find.byType(Image), ready ? findsNothing : findsOneWidget);
      if (!ready) {
        final image = t.widget<Image>(find.byType(Image));
        expect(identical(image.image, first), true);
        expect(image.fit, BoxFit.fill);
        expect(image.gaplessPlayback, true);
      }
    }
    await status(false, revision: 2);
    final second = t.widget<Image>(find.byType(Image)).image as MemoryImage;
    expect(identical(first, second), false);
    expect(PaintingBinding.instance.imageCache.containsKey(first), false);
    await t
        .runAsync(() => precacheImage(second, t.element(find.byType(Image))));
    await status(true, revision: 2);
    expect(find.byType(Image), findsNothing);
    await show(moving: true);
    expect(t.widget<Image>(find.byType(Image)).image, same(second));
    await show();
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Texture), findsNothing);
    expect(find.byKey(const ValueKey('map-preview-background')), findsNothing);
    await status(false, revision: null);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(PaintingBinding.instance.imageCache.containsKey(second), false);
    await status(false, revision: 3);
    final last = t.widget<Image>(find.byType(Image)).image as MemoryImage;
    await t.runAsync(() => precacheImage(last, t.element(find.byType(Image))));
    expect(PaintingBinding.instance.imageCache.containsKey(last), true);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
    expect(PaintingBinding.instance.imageCache.containsKey(last), false);
    expect(created, [id]);
    expect(disposed, [id]);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
