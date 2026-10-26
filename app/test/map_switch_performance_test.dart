import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_launcher/model/appearance.dart';
import 'package:uni_launcher/theme/launcher_theme.dart';
import 'package:uni_launcher/widgets/page_transition.dart';
import 'embedded_navigation_lifetime_test.dart' show LiveMapHarness;

void main() {
  testWidgets(
      'live map survives page reversal and only hides for inactive page or settings',
      (t) async {
    final h = LiveMapHarness(t);
    Future<void> show(int page,
        {bool settings = false, String effect = 'slide'}) async {
      h.controller.settings = settings;
      await t.pumpWidget(MaterialApp(
          theme: launcherTheme(SurfaceStyle.from(const Appearance(), false)),
          home: Scaffold(
              body: DesktopPageStack(page: page, effect: effect, children: [
            h.card(active: page == 0),
            const Text('other page')
          ]))));
      await h.flush();
    }

    await show(0);
    final texture = find.byKey(const ValueKey('map-live-texture'));
    final original = t.element(texture);
    expect(h.visibility, [true]);
    expect(h.creates, hasLength(1));
    await show(1);
    expect(h.visibility.last, false);
    expect(find.byKey(const ValueKey('map-live-texture'), skipOffstage: false),
        findsOneWidget);
    await t.pump(const Duration(milliseconds: 500));
    await show(0);
    await t.pump(const Duration(milliseconds: 60));
    expect(h.visibility.last, true, reason: 'incoming motion must stay live');
    expect(t.element(texture), same(original));
    expect(t.widget<Texture>(texture).textureId, 71);
    await show(1); // Reverse before the incoming animation finishes.
    expect(h.visibility.last, false);
    await show(0);
    expect(h.visibility.last, true);
    await t.pump(const Duration(milliseconds: 500));
    await h.status(false);
    expect(t.element(texture), same(original));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await h.status(true);
    await show(0, settings: true);
    expect(h.visibility.last, false);
    await show(0, effect: 'fade');
    expect(h.visibility.last, true);
    expect(t.element(texture), same(original));
    expect(h.resizes, isEmpty,
        reason: 'animation transforms do not resize the display');
    expect(h.creates, hasLength(1));
    expect(h.disposed, isEmpty);
    expect(h.platformCalls, isEmpty);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
