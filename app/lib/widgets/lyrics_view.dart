import 'dart:async';
import 'package:flutter/material.dart';
import '../model/lyrics.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';

/// Reused by the card and detail panel; scrolls only on a timestamp change.
class LyricsView extends StatefulWidget {
  final Map<String, dynamic> media;
  final bool compact;
  final TextAlign textAlign;
  const LyricsView(
      {super.key,
      required this.media,
      this.compact = false,
      this.textAlign = TextAlign.center});
  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final scroll = ScrollController();
  Timer? timer;
  Lyrics lyrics = const Lyrics([]);
  int active = -1;
  String payload = '';
  double get rowHeight => Design.px(36);
  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void didUpdateWidget(LyricsView old) {
    super.didUpdateWidget(old);
    refresh();
  }

  void refresh() {
    final next = widget.media['lyrics'] is String
        ? widget.media['lyrics'] as String
        : '';
    final changed = payload != next;
    if (changed) {
      payload = next;
      lyrics = Lyrics.parse(next);
      active = -1;
    }
    timer?.cancel();
    updateLine(reset: changed);
    if (lyrics.timed &&
        widget.media['playing'] == true &&
        widget.media['positionKnown'] == true)
      timer = Timer.periodic(
          const Duration(milliseconds: 250), (_) => updateLine());
  }

  void updateLine({bool reset = false}) {
    final timeline = MediaTimeline.fromJson(widget.media);
    final next = timeline.known
        ? lyrics.activeAt(timeline.at(DateTime.now().millisecondsSinceEpoch))
        : -1;
    if (next == active && !reset) return;
    if (mounted) setState(() => active = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      final target = ((next < 0 ? 0 : next) * rowHeight)
          .clamp(0.0, scroll.position.maxScrollExtent);
      if (reset || MediaQuery.disableAnimationsOf(context)) {
        scroll.jumpTo(target);
      } else {
        scroll.animateTo(target,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    final count = widget.compact ? 1 : 3;
    if (lyrics.lines.isEmpty)
      return SizedBox(
          height: rowHeight * count,
          child: Center(
              child: Text('当前音源未提供歌词',
                  key: const ValueKey('lyrics-empty'),
                  style: TextStyle(fontSize: Design.px(19), color: s.muted))));
    return Semantics(
        label: '歌词',
        child: SizedBox(
            height: rowHeight * count,
            child: ListView.builder(
              key: const ValueKey('lyrics-scroll'),
              controller: scroll,
              padding: EdgeInsets.symmetric(
                  vertical: widget.compact ? 0 : rowHeight),
              itemExtent: rowHeight,
              itemCount: lyrics.lines.length,
              itemBuilder: (context, i) => Align(
                  alignment: widget.textAlign == TextAlign.start
                      ? Alignment.centerLeft
                      : Alignment.center,
                  child: Text(lyrics.lines[i].text,
                      key: ValueKey(
                          'lyric-line-$i-${active == i ? "active" : "idle"}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: widget.textAlign,
                      style: TextStyle(
                          fontSize: Design.px(widget.compact ? 20 : 22),
                          color: i == active ? s.accent : s.muted,
                          fontWeight: i == active
                              ? FontWeight.w500
                              : FontWeight.w400))),
            )));
  }
}
