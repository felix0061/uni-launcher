/// A received batch is atomic. No directions are accumulated between updates.
class TrafficSignal {
  final String direction, lamp;
  final int? countdownSeconds;
  const TrafficSignal(
      {this.direction = 'unknown',
      this.lamp = 'unknown',
      this.countdownSeconds});

  String get directionLabel =>
      const {
        'left': '左转',
        'straight': '直行',
        'right': '右转',
        'uturn': '掉头',
      }[direction] ??
      '路口信号';
  String get lampLabel =>
      const {
        'red': '红灯',
        'green': '绿灯',
        'amber': '黄灯',
      }[lamp] ??
      '灯态待确认';

  int? remaining(int elapsedMs) {
    final seconds = countdownSeconds;
    if (seconds == null) return null;
    final value = seconds - elapsedMs ~/ 1000;
    return value > 0 ? value : null; // Zero never implies a signal change.
  }
}

class TrafficLightSnapshot {
  final List<TrafficSignal> lights;
  final String reason, package;
  final int ageMs, ttlMs, sequence;
  final bool available, demo;
  const TrafficLightSnapshot(
      {this.lights = const [],
      this.reason = 'waiting',
      this.package = '',
      this.ageMs = 0,
      this.ttlMs = 5000,
      this.sequence = 0,
      this.available = false,
      this.demo = false});

  factory TrafficLightSnapshot.fromNative(Map<String, dynamic> native) {
    if (native['demo'] == true) {
      // Explicit demo mode only. Never persist or mix these with live data.
      return const TrafficLightSnapshot(available: true, demo: true, lights: [
        TrafficSignal(direction: 'left', lamp: 'red', countdownSeconds: 60),
        TrafficSignal(
            direction: 'straight', lamp: 'green', countdownSeconds: 24),
      ]);
    }
    final raw = native['trafficLights'];
    if (raw is! Map) return const TrafficLightSnapshot();
    final age = _integer(raw['ageMs']), ttl = _integer(raw['ttlMs']);
    final valid = raw['available'] == true &&
        age != null &&
        age >= 0 &&
        ttl != null &&
        ttl > 0 &&
        ttl <= 5000 &&
        age < ttl;
    final list = raw['lights'];
    final lights = <TrafficSignal>[];
    if (valid && list is List && list.length <= 16) {
      for (final item in list) {
        if (item is! Map) return const TrafficLightSnapshot();
        final count = _integer(item['countdownSeconds']);
        final verified = raw['enumVerified'] == true;
        lights.add(TrafficSignal(
            direction: verified &&
                    const {'left', 'straight', 'right', 'uturn'}
                        .contains(item['direction'])
                ? item['direction'] as String
                : 'unknown',
            lamp: verified &&
                    const {'red', 'green', 'amber'}.contains(item['lamp'])
                ? item['lamp'] as String
                : 'unknown',
            countdownSeconds:
                count != null && count >= 0 && count <= 999 ? count : null));
      }
    }
    return TrafficLightSnapshot(
        lights: List.unmodifiable(lights),
        reason: raw['reason'] == 'expired' ||
                (age != null && ttl != null && age >= ttl)
            ? 'expired'
            : 'waiting',
        package: raw['package'] is String ? raw['package'] as String : '',
        ageMs: age ?? 0,
        ttlMs: ttl ?? 5000,
        sequence: _integer(raw['sequence']) ?? 0,
        available: valid && lights.isNotEmpty);
  }

  bool liveAt(int sinceSnapshotMs) =>
      available && (demo || ageMs + sinceSnapshotMs < ttlMs);
  int elapsedAt(int sinceSnapshotMs) => demo ? 0 : ageMs + sinceSnapshotMs;

  static int? _integer(Object? value) => value is num &&
          value.isFinite &&
          value == value.roundToDouble() &&
          value >= 0 &&
          value <= 2147483647
      ? value.toInt()
      : null;
}
