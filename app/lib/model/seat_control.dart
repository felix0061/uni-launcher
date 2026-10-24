/// Seat actuators require a per-control capability, separate from general HVAC.
class SeatControlState {
  final bool writable;
  final int? level;
  const SeatControlState({required this.writable, required this.level});
  factory SeatControlState.fromNative(Map<String, dynamic> native, String key) {
    final demo = native['demo'] == true;
    final vehicle = native['vehicle'] is Map ? native['vehicle'] as Map : {};
    final capabilities = vehicle['seatCapabilities'] is Map
        ? vehicle['seatCapabilities'] as Map
        : {};
    final capability = capabilities[key] is Map ? capabilities[key] as Map : {};
    final climate = native['climate'] is Map ? native['climate'] as Map : {};
    final raw = climate[key];
    final readable = demo ||
        (capability['supported'] == true && capability['readable'] == true);
    return SeatControlState(
        writable: demo ||
            (capability['supported'] == true && capability['writable'] == true),
        level: readable && raw is int && raw >= 0 && raw <= 3 ? raw : null);
  }
}
