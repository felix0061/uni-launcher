import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_launcher/controller/launcher_controller.dart';
import 'package:uni_launcher/launcher_app.dart';
import 'package:uni_launcher/model/appearance.dart';
import 'package:uni_launcher/model/lyrics.dart';
import 'package:uni_launcher/widgets/lyrics_view.dart';
import 'package:uni_launcher/widgets/media_progress.dart';
import 'package:uni_launcher/widgets/page_transition.dart';
import 'fake_gateway.dart';
import 'package:uni_launcher/theme/launcher_theme.dart';
import 'package:uni_launcher/theme/design_tokens.dart';

void main() {
  test('LRC supports multiple timestamps, precision, offset and backward seek',
      () {
    final l = Lyrics.parse(
        '[ar:Artist]\n[offset:-500]\n[00:01.2][00:03.25]重复行\n[00:02.123]另一行\n[00:65]非法秒');
    expect(l.timed, true);
    expect(l.lines.map((v) => v.timeMs), [700, 1623, 2750]);
    expect(l.activeAt(699), -1);
    expect(l.activeAt(1623), 1);
    expect(l.activeAt(5000), 2);
    expect(l.activeAt(800), 0);
    expect(l.lines.map((v) => v.text), ['重复行', '另一行', '重复行']);
  });
  test(
      'Plain lyrics have no fabricated timing; malformed and oversized inputs are bounded',
      () {
    final l = Lyrics.parse('第一行\n第二行');
    expect(l.timed, false);
    expect(l.activeAt(90000), -1);
    expect(l.lines.length, 2);
    expect(Lyrics.parse(null).lines, isEmpty);
    expect(Lyrics.parse('x' * 131073).lines, isEmpty);
  });
  test('Playback clock extrapolates speed, pauses and clamps duration', () {
    Map<String, dynamic> state = {
      'positionMs': 1000,
      'sampledAtMs': 10000,
      'durationMs': 5000,
      'speed': 2,
      'playing': true,
      'positionKnown': true
    };
    expect(MediaTimeline.fromJson(state).at(11000), 3000);
    expect(MediaTimeline.fromJson(state).at(15000), 5000);
    expect(
        MediaTimeline.fromJson({...state, 'playing': false}).at(15000), 1000);
    expect(MediaTimeline.fromJson(state).at(9000), 1000);
  });
  testWidgets(
      'Lyrics follow progress, seek backward and clear on track without lyrics',
      (t) async {
    Future<void> display(String lyrics, int position) async {
      await t.pumpWidget(MaterialApp(
          theme: launcherTheme(SurfaceStyle.from(const Appearance(), true)),
          home: Scaffold(
              body: SizedBox(
                  width: 400,
                  child: LyricsView(media: {
                    'lyrics': lyrics,
                    'playing': false,
                    'positionMs': position,
                    'positionKnown': true
                  })))));
      await t.pumpAndSettle();
    }

    const lrc = '[00:00]第一行\n[00:03]第二行\n[00:06]第三行\n[00:09]第四行';
    await display(lrc, 6500);
    expect(find.byKey(const ValueKey('lyric-line-2-active')), findsOneWidget);
    final scroll = t.state<ScrollableState>(find.descendant(
        of: find.byKey(const ValueKey('lyrics-scroll')),
        matching: find.byType(Scrollable)));
    expect(scroll.position.pixels, 60);
    await display(lrc, 1000);
    expect(scroll.position.pixels, 0);
    expect(find.byKey(const ValueKey('lyric-line-0-active')), findsOneWidget);
    await display('', 0);
    expect(find.byKey(const ValueKey('lyrics-empty')), findsOneWidget);
    expect(find.text('第三行'), findsNothing);
    expect(t.takeException(), null);
  });
  testWidgets(
      'current dock lyric wraps to two lines and centers short and long text',
      (t) async {
    Future<void> show(String line) async {
      await t.pumpWidget(MaterialApp(
          theme: launcherTheme(SurfaceStyle.from(const Appearance(), true)),
          home: Scaffold(
              body: SizedBox(
                  width: 240,
                  height: 80,
                  child: LyricsView(
                      media: {'lyricLine': line},
                      currentLineMaxLines: 2,
                      lineHeight: 32,
                      fontSize: 26)))));
      await t.pumpAndSettle();
    }

    const key = ValueKey('current-lyric-wrapped');
    await show('一句歌词');
    final single = t.getSize(find.byKey(key)).height;
    expect(t.getCenter(find.byKey(key)), t.getCenter(find.byType(LyricsView)));
    await show('这是一句需要自动换行且超过两行时以省略号结束的很长歌词' * 3);
    expect(t.getSize(find.byKey(key)).height, closeTo(single * 2, .1));
    expect(t.getCenter(find.byKey(key)), t.getCenter(find.byType(LyricsView)));
    final text = t.widget<Text>(find.byKey(key));
    expect(text.maxLines, 2);
    expect(text.softWrap, true);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.textAlign, TextAlign.center);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'single-line dock keeps a long unavailable-lyrics reason inside its row',
      (t) async {
    await t.pumpWidget(MaterialApp(
        theme: launcherTheme(SurfaceStyle.from(const Appearance(), true)),
        home: Scaffold(
            body: SizedBox(
                width: 240,
                child: LyricsView(
                    visibleLines: 1,
                    lineHeight: 40,
                    fontSize: 26,
                    media: const {
                      'lyricsReason': '网易云当前版本未向桌面共享歌词，请选择其他音源'
                    })))));
    await t.pumpAndSettle();
    final label = t.widget<Text>(find.byKey(const ValueKey('lyrics-empty')));
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
    expect(t.getSize(find.byType(LyricsView)).height, Design.px(40));
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'Three-line source callbacks keep real neighbors and current line centered',
      (t) async {
    await t.pumpWidget(MaterialApp(
        theme: launcherTheme(SurfaceStyle.from(const Appearance(), true)),
        home: Scaffold(
            body: SizedBox(
                width: 400,
                child: LyricsView(
                    visibleLines: 3,
                    lineHeight: 22,
                    fontSize: 16,
                    media: const {
                      'lyricPrevious': '已唱过',
                      'lyricLine': '正在唱',
                      'lyricNext': '将唱到'
                    })))));
    await t.pumpAndSettle();
    expect(find.text('已唱过'), findsOneWidget);
    expect(find.text('正在唱'), findsOneWidget);
    expect(find.text('将唱到'), findsOneWidget);
    expect(t.getCenter(find.text('正在唱')).dy,
        closeTo(t.getCenter(find.byType(LyricsView)).dy, .1));
  });
  testWidgets(
      'Seek gesture sends one bounded position and unsupported source is read only',
      (t) async {
    final positions = <int>[];
    Future<void> display(bool supported) async {
      await t.pumpWidget(MaterialApp(
          theme: launcherTheme(SurfaceStyle.from(const Appearance(), true)),
          home: Scaffold(
              body: SizedBox(
                  width: 600,
                  child: MediaProgress(
                    media: {
                      'durationMs': 180000,
                      'positionMs': 10000,
                      'positionKnown': true,
                      'playing': false,
                      'canSeek': supported
                    },
                    onSeek: positions.add,
                  )))));
      await t.pumpAndSettle();
    }

    await display(true);
    final slider = find.byKey(const ValueKey('media-seek'));
    await t.drag(slider, const Offset(200, 0));
    await t.pumpAndSettle();
    expect(positions.length, 1);
    expect(positions.single, inInclusiveRange(10000, 180000));
    await display(false);
    expect(find.byType(Slider), findsNothing);
    expect(positions.length, 1);
  });
  test('Transition preference has a safe default and round trips', () {
    expect(Appearance.fromJson({}).pageTransition, 'none');
    expect(Appearance.fromJson({'pageTransition': 'unknown'}).pageTransition,
        'none');
    for (final effect in ['none', 'slide', 'fade']) {
      expect(
          Appearance.fromJson(
                  const Appearance().copyWith(pageTransition: effect).toJson())
              .pageTransition,
          effect);
    }
  });
  testWidgets(
      'Motion setting persists and fast page changes paint only incoming workspace',
      (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    final g = FakeGateway(), c = LauncherController(g);
    await c.initialize();
    await t.pumpWidget(LauncherApp(controller: c));
    await t.pumpAndSettle();
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      c.dispose();
      await g.dispose();
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
    c.openSettings();
    c.tab('motion');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('transition-slide')));
    await t.pumpAndSettle();
    expect(jsonDecode(g.saved!)['preferences']['pageTransition'], 'slide');
    c.home();
    await t.pumpAndSettle();
    final dockBefore = t.getRect(find.byKey(const ValueKey('bottom-dock')));
    final indicatorStart =
        t.getRect(find.byKey(const ValueKey('page-indicator-active'))).left;
    await t.fling(
        find.byKey(const ValueKey('card-grid')), const Offset(-550, 0), 1000);
    await t.pump();
    expect(c.page, 1);
    await t.pump(const Duration(milliseconds: 70));
    final indicatorMid =
        t.getRect(find.byKey(const ValueKey('page-indicator-active'))).left;
    expect(indicatorMid, greaterThan(indicatorStart));
    expect(
        find.descendant(
            of: find.byType(DesktopPageStack),
            matching: find.byType(FractionalTranslation)),
        findsOneWidget);
    expect(find.byKey(const ValueKey('nav-1')), findsNothing,
        reason: 'the outgoing card-heavy page is not painted');
    expect(find.byKey(const ValueKey('tpms-1')), findsOneWidget);
    await t.pumpAndSettle();
    final indicatorEnd =
        t.getRect(find.byKey(const ValueKey('page-indicator-active'))).left;
    expect(indicatorEnd, greaterThan(indicatorMid));
    expect(t.getRect(find.byKey(const ValueKey('bottom-dock'))), dockBefore);
    expect(find.byKey(const ValueKey('nav-1')), findsNothing);
    expect(find.byKey(const ValueKey('tpms-1')), findsOneWidget);
    c.setAppearance(c.appearance.copyWith(pageTransition: 'fade'));
    await t.pumpAndSettle();
    c.switchPage(0);
    await t.pump();
    expect(
        find.descendant(
            of: find.byType(DesktopPageStack), matching: find.byType(Opacity)),
        findsOneWidget);
    expect(find.byKey(const ValueKey('nav-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('tpms-1')), findsNothing);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('nav-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('tpms-1')), findsNothing);
    c.setAppearance(c.appearance.copyWith(pageTransition: 'none'));
    await t.pumpAndSettle();
    c.switchPage(1);
    await t.pump();
    expect(find.byKey(const ValueKey('nav-1')), findsNothing);
    expect(
        find.descendant(
            of: find.byType(DesktopPageStack), matching: find.byType(Opacity)),
        findsNothing);
    expect(t.takeException(), null);
  });
  testWidgets('System reduced motion disables workspace animation', (t) async {
    await t.pumpWidget(const MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: DesktopPageStack(
                page: 0,
                effect: 'slide',
                children: [Text('page 1'), Text('page 2')]))));
    expect(
        find.descendant(
            of: find.byType(DesktopPageStack),
            matching: find.byType(FractionalTranslation)),
        findsNothing);
    expect(find.text('page 1'), findsOneWidget);
    expect(find.text('page 2'), findsNothing);
  });
}
