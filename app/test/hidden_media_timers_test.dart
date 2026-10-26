import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_launcher/model/appearance.dart';
import 'package:uni_launcher/theme/launcher_theme.dart';
import 'package:uni_launcher/widgets/lyrics_view.dart';
import 'package:uni_launcher/widgets/media_progress.dart';
import 'package:uni_launcher/widgets/native_slice_builder.dart';

Map<String, dynamic> _sample(int position, {bool playing = true}) => {
      'lyrics': '[00:00]First line\n[00:30]Latest line\n[01:00]Next line',
      'positionKnown': true,
      'positionMs': position,
      'durationMs': 120000,
      'playing': playing,
    };

Widget _mediaPair(String name, ValueListenable<Map<String, dynamic>> media) =>
    NativeSliceBuilder(
        valueListenable: media,
        select: (value) => value,
        builder: (_, value) => SizedBox(
            width: 500,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              LyricsView(
                  key: ValueKey('$name-lyrics'),
                  media: value,
                  currentLineMaxLines: 2),
              MediaProgress(key: ValueKey('$name-progress'), media: value),
            ])));

Widget _harness(ValueNotifier<Map<String, dynamic>> media,
    ValueNotifier<bool> pageVisible, ValueNotifier<bool> motionIdle,
    {bool withDock = false}) {
  final page = _mediaPair('page', media);
  return MaterialApp(
      theme: launcherTheme(SurfaceStyle.from(const Appearance(), true)),
      home: Scaffold(
          body: Column(children: [
        ValueListenableBuilder<bool>(
            valueListenable: motionIdle,
            child: ValueListenableBuilder<bool>(
                valueListenable: pageVisible,
                child: page,
                builder: (_, enabled, child) =>
                    TickerMode(enabled: enabled, child: child!)),
            builder: (_, enabled, child) =>
                TickerMode(enabled: enabled, child: child!)),
        if (withDock) _mediaPair('dock', media),
      ])));
}

Finder _widget(String name, String kind) => find.byKey(ValueKey('$name-$kind'));

// Check the actual periodic timers as well as rebuild counts: a lyric timer
// that wakes up but happens to stay on the same line is still unwanted work.
Timer? _timer(WidgetTester tester, String name, String kind) =>
    (tester.state(_widget(name, kind)) as dynamic).timer as Timer?;

void main() {
  for (final reason in ['hidden page', 'workspace motion']) {
    testWidgets('$reason stops timers and resumes the latest deferred sample',
        (tester) async {
      final media = ValueNotifier(_sample(1000));
      final visible = ValueNotifier(true);
      final idle = ValueNotifier(true);
      final enabled = reason == 'hidden page' ? visible : idle;
      final rebuilds = <Key?, int>{};
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        previous?.call(element, builtOnce);
        if (element.widget is LyricsView || element.widget is MediaProgress) {
          final key = element.widget.key;
          rebuilds[key] = (rebuilds[key] ?? 0) + 1;
        }
      };
      addTearDown(() {
        debugOnRebuildDirtyWidget = previous;
        media.dispose();
        visible.dispose();
        idle.dispose();
      });
      await tester.pumpWidget(_harness(media, visible, idle));
      await tester.pumpAndSettle();
      final lyricState = tester.state(_widget('page', 'lyrics'));
      final progressState = tester.state(_widget('page', 'progress'));
      final lyricTimer = _timer(tester, 'page', 'lyrics')!;
      final progressTimer = _timer(tester, 'page', 'progress')!;
      expect(lyricTimer.isActive, isTrue);
      expect(progressTimer.isActive, isTrue);
      expect(find.text('First line'), findsOneWidget);
      expect(find.text('00:01'), findsOneWidget);

      enabled.value = false;
      await tester.pumpAndSettle();
      expect(lyricTimer.isActive, isFalse);
      expect(progressTimer.isActive, isFalse);
      expect(_timer(tester, 'page', 'lyrics'), isNull);
      expect(_timer(tester, 'page', 'progress'), isNull);
      final hiddenRebuilds = Map<Key?, int>.of(rebuilds);
      media.value = _sample(45000);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
        expect(rebuilds, hiddenRebuilds);
        expect(tester.binding.hasScheduledFrame, isFalse);
      }
      // NativeSliceBuilder retained the visible sample while disabled.
      expect(find.text('First line'), findsOneWidget);
      expect(find.text('00:01'), findsOneWidget);

      enabled.value = true;
      await tester.pumpAndSettle();
      expect(tester.state(_widget('page', 'lyrics')), same(lyricState));
      expect(tester.state(_widget('page', 'progress')), same(progressState));
      expect(find.text('Latest line'), findsOneWidget);
      expect(find.text('00:45'), findsOneWidget);
      expect(_timer(tester, 'page', 'lyrics')!.isActive, isTrue);
      expect(_timer(tester, 'page', 'progress')!.isActive, isTrue);
      final beforeTick = rebuilds[const ValueKey('page-progress')]!;
      await tester.pump(const Duration(seconds: 1));
      expect(
          rebuilds[const ValueKey('page-progress')], greaterThan(beforeTick));

      // Repeated visibility changes must cancel the replacement timers too.
      final resumedLyricTimer = _timer(tester, 'page', 'lyrics')!;
      final resumedProgressTimer = _timer(tester, 'page', 'progress')!;
      enabled.value = false;
      await tester.pump();
      expect(resumedLyricTimer.isActive, isFalse);
      expect(resumedProgressTimer.isActive, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'initially muted media never starts timers; paused resume stays idle',
      (tester) async {
    final media = ValueNotifier(_sample(1000));
    final visible = ValueNotifier(false);
    final idle = ValueNotifier(true);
    addTearDown(() {
      media.dispose();
      visible.dispose();
      idle.dispose();
    });
    await tester.pumpWidget(_harness(media, visible, idle));
    expect(_timer(tester, 'page', 'lyrics'), isNull);
    expect(_timer(tester, 'page', 'progress'), isNull);
    await tester.pump(const Duration(seconds: 5));
    media.value = _sample(65000, playing: false);
    visible.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Next line'), findsOneWidget);
    expect(find.text('01:05'), findsOneWidget);
    expect(_timer(tester, 'page', 'lyrics'), isNull);
    expect(_timer(tester, 'page', 'progress'), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('workspace motion leaves the visible global dock timers running',
      (tester) async {
    final media = ValueNotifier(_sample(1000));
    final visible = ValueNotifier(true);
    final idle = ValueNotifier(true);
    addTearDown(() {
      media.dispose();
      visible.dispose();
      idle.dispose();
    });
    await tester.pumpWidget(_harness(media, visible, idle, withDock: true));
    await tester.pumpAndSettle();
    final dockLyricTimer = _timer(tester, 'dock', 'lyrics')!;
    final dockProgressTimer = _timer(tester, 'dock', 'progress')!;
    idle.value = false;
    await tester.pumpAndSettle();
    expect(_timer(tester, 'page', 'lyrics'), isNull);
    expect(_timer(tester, 'page', 'progress'), isNull);
    expect(dockLyricTimer.isActive, isTrue);
    expect(dockProgressTimer.isActive, isTrue);

    media.value = _sample(45000);
    await tester.pumpAndSettle();
    expect(find.text('First line'), findsOneWidget);
    expect(find.text('Latest line'), findsOneWidget);
    expect(find.text('00:01'), findsOneWidget);
    expect(find.text('00:45'), findsOneWidget);
    expect(_timer(tester, 'dock', 'lyrics')!.isActive, isTrue);
    expect(_timer(tester, 'dock', 'progress')!.isActive, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(_timer(tester, 'page', 'lyrics'), isNull);
    expect(_timer(tester, 'dock', 'lyrics')!.isActive, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'resume extrapolates the old sample and jumps to the current verse',
      (tester) async {
    final visible = ValueNotifier(false);
    addTearDown(visible.dispose);
    final media = {
      ..._sample(1000),
      'sampledAtMs': DateTime.now().millisecondsSinceEpoch - 45000,
    };
    await tester.pumpWidget(MaterialApp(
        theme: launcherTheme(SurfaceStyle.from(const Appearance(), true)),
        home: Scaffold(
            body: ValueListenableBuilder<bool>(
                valueListenable: visible,
                child: SizedBox(
                    width: 500,
                    child: Column(children: [
                      LyricsView(
                          key: const ValueKey('page-lyrics'), media: media),
                      MediaProgress(
                          key: const ValueKey('page-progress'), media: media),
                    ])),
                builder: (_, enabled, child) =>
                    TickerMode(enabled: enabled, child: child!)))));
    expect(_timer(tester, 'page', 'lyrics'), isNull);
    expect(_timer(tester, 'page', 'progress'), isNull);
    // No new native sample is supplied on resume: use sampledAtMs to catch up.
    visible.value = true;
    await tester.pump();
    expect(find.byKey(const ValueKey('lyric-line-1-active')), findsOneWidget);
    final scroll = tester.state<ScrollableState>(find.descendant(
        of: find.byKey(const ValueKey('lyrics-scroll')),
        matching: find.byType(Scrollable)));
    expect(scroll.position.pixels, greaterThan(0));
    expect(scroll.position.isScrollingNotifier.value, isFalse);
    final elapsedText = tester.widgetList<Text>(find.descendant(
        of: _widget('page', 'progress'), matching: find.byType(Text)));
    expect(elapsedText.first.data, startsWith('00:4'));
    expect(_timer(tester, 'page', 'lyrics')!.isActive, isTrue);
    expect(_timer(tester, 'page', 'progress')!.isActive, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
