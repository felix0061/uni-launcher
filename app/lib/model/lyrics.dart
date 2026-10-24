class LyricLine {
  final int? timeMs;
  final String text;
  const LyricLine(this.text, [this.timeMs]);
}

/// LRC or plain text from the active source. Never invent timing for plain text.
class Lyrics {
  final List<LyricLine> lines;
  final bool timed;
  const Lyrics(this.lines, {this.timed = false});
  factory Lyrics.parse(Object? payload) {
    if (payload is! String || payload.length > 131072) return const Lyrics([]);
    final tags = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
    final offsetTag = RegExp(r'\[offset:([+-]?\d+)\]', caseSensitive: false)
        .firstMatch(payload);
    final offset = int.tryParse(offsetTag?.group(1) ?? '') ?? 0;
    final timed = <LyricLine>[], plain = <LyricLine>[];
    for (final raw in payload.split(RegExp(r'\r?\n')).take(2000)) {
      final matches = tags.allMatches(raw).toList();
      final text = raw.replaceAll(tags, '').trim();
      if (text.isEmpty ||
          RegExp(r'^\[[a-z]+:.*\]$', caseSensitive: false).hasMatch(text))
        continue;
      if (matches.isEmpty) {
        plain.add(LyricLine(text));
        continue;
      }
      for (final match in matches) {
        final seconds = int.parse(match.group(2)!);
        if (seconds >= 60) continue;
        final fraction = (match.group(3) ?? '').padRight(3, '0');
        final time = int.parse(match.group(1)!) * 60000 +
            seconds * 1000 +
            int.parse(fraction) +
            offset;
        timed.add(LyricLine(text, time.clamp(0, 2147483647)));
      }
    }
    timed.sort((a, b) => a.timeMs!.compareTo(b.timeMs!));
    return timed.isEmpty ? Lyrics(plain) : Lyrics(timed, timed: true);
  }
  int activeAt(int positionMs) {
    if (!timed || lines.isEmpty || positionMs < lines.first.timeMs!) return -1;
    int low = 0, high = lines.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (lines[mid].timeMs! <= positionMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low - 1;
  }
}

class MediaTimeline {
  final int positionMs, durationMs, sampledAtMs;
  final double speed;
  final bool playing, known;
  MediaTimeline.fromJson(Map<String, dynamic> media)
      : positionMs = (media['positionMs'] as num?)?.toInt() ?? 0,
        durationMs = (media['durationMs'] as num?)?.toInt() ?? 0,
        sampledAtMs = (media['sampledAtMs'] as num?)?.toInt() ?? 0,
        speed = (media['speed'] as num?)?.toDouble() ?? 1,
        playing = media['playing'] == true,
        known = media['positionKnown'] == true;
  int at(int nowMs) {
    final elapsed = playing && sampledAtMs > 0
        ? (nowMs - sampledAtMs).clamp(0, 86400000) * speed
        : 0;
    return (positionMs + elapsed)
        .round()
        .clamp(0, durationMs > 0 ? durationMs : 2147483647);
  }
}
