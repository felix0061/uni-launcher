import 'dart:async';
import 'package:uni_launcher/platform/native_gateway.dart';

class FakeGateway implements NativeGateway {
  final stream = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  Map<String, dynamic> state = {
    'demo': true,
    'dark': true,
    'hideNavigation': false,
    'globalNavigationGranted': false,
    'apps': <dynamic>[],
    'climate': {
      'left': 22.5,
      'right': 22.5,
      'fan': 3,
      'driverHeat': 0,
      'driverVent': 0,
      'passengerHeat': 0,
      'auto': true,
      'ac': true,
      'sync': false,
      'power': true
    },
    'media': {
      'title': '向海而行',
      'artist': 'Coastline',
      'available': true,
      'playing': true
    },
    'vehicle': {'writable': false, 'reason': '模拟器没有原车框架'},
    'savedDesign': ''
  };
  String? saved;
  final List<Map<String, dynamic>> commands = [];
  @override
  Future<Map<String, dynamic>> bootstrap() async => Map.of(state);
  @override
  Stream<Map<String, dynamic>> get events => stream.stream;
  @override
  Future<void> action(String action,
      {String? value, String? zone, bool? enabled}) async {
    commands.add(
        {'action': action, 'value': value, 'zone': zone, 'enabled': enabled});
    if (action == 'hide-navigation')
      state = {...state, 'hideNavigation': enabled};
    if (action == 'demo-mode') state = {...state, 'demo': enabled};
    stream.add(Map.of(state));
  }

  @override
  Future<void> save(String value) async {
    saved = value;
  }

  @override
  void onHome(void Function() callback) {}
  Future<void> dispose() => stream.close();
}
