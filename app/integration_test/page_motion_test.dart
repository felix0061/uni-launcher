import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uni_launcher/controller/launcher_controller.dart';
import 'package:uni_launcher/launcher_app.dart';
import 'package:uni_launcher/model/page_motion.dart';
import 'package:uni_launcher/widgets/page_transition.dart';
import '../test/fake_gateway.dart';

/// Production widgets + synthetic telemetry. Profile numbers describe this
/// emulator only, not the real 820A or AMap's independent rendering workload.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('profile normal Android surface without screenshot readback',
      (t) async {
    final g = FakeGateway(), c = LauncherController(g);
    await c.initialize();
    c.setAppearance(c.appearance.copyWith(mode: 'dark'), save: false);
    await t.pumpWidget(LauncherApp(controller: c));
    await t.pumpAndSettle();
    for (final effect in pageEffects) {
      c.setAppearance(c.appearance.copyWith(pageTransition: effect.id),
          save: false);
      await t.pumpAndSettle();
      await c.switchPage(1);
      await t.pumpAndSettle();
      await c.switchPage(0);
      await t.pumpAndSettle();
      final frames = <FrameTiming>[];
      void collect(List<FrameTiming> sample) => frames.addAll(sample);
      await Future<void>.delayed(const Duration(seconds: 1));
      SchedulerBinding.instance.addTimingsCallback(collect);
      try {
        for (var run = 0; run < 12; run++) {
          await c.switchPage(run.isEven ? 1 : 0);
          await t.pump();
          for (var frame = 0; frame < 19; frame++) {
            if (frame % 4 == 0)
              g.stream.add({...g.state, 'sample': run * 19 + frame});
            await t.pump(const Duration(milliseconds: 16));
          }
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      } finally {
        SchedulerBinding.instance.removeTimingsCallback(collect);
      }
      expect(frames, isNotEmpty);
      binding.reportData = {
        ...?binding.reportData,
        'frames-${effect.id}': _summarize(frames)
      };
    }
    binding.reportData = {
      ...?binding.reportData,
      'performanceSurface':
          'Normal Flutter SurfaceView; measured BEFORE screenshot conversion; warmed pages; glass disabled',
      'performanceScope':
          'Steady-state page switches with synthetic gateway events, no screenshot capture or VM timeline service in measured interval'
    };
    await t.pumpWidget(const SizedBox.shrink());
    c.dispose();
    await g.dispose();
  });
  testWidgets('workspace effects render, track touch and retain fixed dock',
      (t) async {
    final g = FakeGateway(), c = LauncherController(g);
    await c.initialize();
    c.setAppearance(c.appearance.copyWith(mode: 'dark'), save: false);
    await t.pumpWidget(LauncherApp(controller: c));
    await t.pumpAndSettle();
    final checks = <String>[];
    void check(String name, bool result) {
      expect(result, isTrue, reason: name);
      checks.add(name);
    }

    await binding.convertFlutterSurfaceToImage();
    await t.pumpAndSettle();
    await binding.takeScreenshot('page-motion-initial');
    final dock = t.getRect(find.byKey(const ValueKey('bottom-dock')));
    final nav = find.byKey(const ValueKey('nav-1'));
    final navElement = t.element(nav), navStart = t.getRect(nav);
    final indicator = find.byKey(const ValueKey('page-indicator-active'));
    final indicatorStart = t.getRect(indicator).left;
    final screen = t.view.physicalSize / t.view.devicePixelRatio;
    final drag =
        await t.startGesture(Offset(screen.width - 80, screen.height * .72));
    await drag.moveBy(const Offset(-30, 0));
    await t.pump();
    await drag.moveBy(Offset(-screen.width * .34, 0));
    await t.pump();
    check('slow drag moves outgoing page before release',
        c.page == 0 && t.getRect(nav).left < navStart.left - 200);
    check('neighbour is visible during drag',
        find.byKey(const ValueKey('tpms-1')).evaluate().length == 1);
    check('indicator tracks same in-flight position',
        t.getRect(indicator).left > indicatorStart + 5);
    check('dock remains fixed during drag',
        t.getRect(find.byKey(const ValueKey('bottom-dock'))) == dock);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await t.pump();
    await binding.takeScreenshot('page-motion-touch-mid');
    await drag.up();
    await t.pumpAndSettle();
    check('slow drag commits without requiring a fling', c.page == 1);
    check('outgoing page is offstage after settle', nav.evaluate().isEmpty);
    await c.switchPage(0);
    await t.pumpAndSettle();
    check('page retains the same card element',
        identical(t.element(nav), navElement));

    for (final effect in pageEffects.where((e) => e.id != 'none')) {
      c.setAppearance(c.appearance.copyWith(pageTransition: effect.id),
          save: false);
      await t.pumpAndSettle();
      final pager =
          t.state<DesktopPageStackState>(find.byType(DesktopPageStack));
      pager.dragStart();
      pager.dragUpdate(-t.getSize(find.byType(DesktopPageStack)).width * .4);
      await t.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await t.pump();
      check(
          '${effect.id}: two pages paint mid-transition',
          nav.evaluate().isNotEmpty &&
              find.byKey(const ValueKey('tpms-1')).evaluate().isNotEmpty);
      final opacities = find
          .descendant(
              of: find.byType(DesktopPageStack), matching: find.byType(Opacity))
          .evaluate()
          .map((e) => (e.widget as Opacity).opacity);
      if (effect.id == 'fade')
        check('${effect.id}: effect opacity is intermediate',
            opacities.any((v) => v > 0 && v < 1));
      await binding.takeScreenshot('page-motion-${effect.id}-mid');
      pager.dragEnd(0);
      await t.pumpAndSettle();
      check('${effect.id}: only target paints after settle',
          nav.evaluate().isEmpty);
      // Warm both pages before measuring repeated steady-state transitions.
      await c.switchPage(0);
      await t.pumpAndSettle();
      for (var run = 0; run < 4; run++) {
        await c.switchPage(run.isEven ? 1 : 0);
        await t.pumpAndSettle();
      }
      check('${effect.id}: repeated transitions retain card element',
          identical(t.element(nav), navElement));
      check('${effect.id}: dock stays fixed after repeated transitions',
          t.getRect(find.byKey(const ValueKey('bottom-dock'))) == dock);
    }
    c.setAppearance(c.appearance.copyWith(pageTransition: 'none'), save: false);
    await t.pumpAndSettle();
    await c.switchPage(1);
    await t.pump();
    check('none switches immediately', nav.evaluate().isEmpty);
    c.openSettings();
    c.tab('motion');
    await t.pumpAndSettle();
    for (final effect in pageEffects) {
      check(
          '${effect.id} setting exists',
          find
              .byKey(ValueKey('transition-${effect.id}'))
              .evaluate()
              .isNotEmpty);
    }
    await binding.takeScreenshot('page-motion-settings');
    check('no framework exceptions', t.takeException() == null);
    binding.reportData = {
      ...?binding.reportData,
      'source':
          'Android 9 emulator / profile mode / production widgets / synthetic telemetry; not 820A or real AMap',
      'checks': checks
    };
    await t.pumpWidget(const SizedBox.shrink());
    c.dispose();
    await g.dispose();
  });
}

Map<String, dynamic> _summarize(List<FrameTiming> frames) {
  Map<String, dynamic> timing(Duration Function(FrameTiming) read) {
    final values = frames.map((f) => read(f).inMicroseconds / 1000).toList()
      ..sort();
    double percentile(double p) => values[((values.length - 1) * p).round()];
    return {
      'p50Ms': percentile(.5),
      'p90Ms': percentile(.9),
      'p99Ms': percentile(.99),
      'maxMs': values.last,
      'over16_67Ms': values.where((v) => v > 16.667).length
    };
  }

  return {
    'frameCount': frames.length,
    'build': timing((f) => f.buildDuration),
    'raster': timing((f) => f.rasterDuration),
    'totalSpan': timing((f) => f.totalSpan)
  };
}
