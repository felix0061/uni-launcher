import 'dart:convert';
import 'package:flutter/services.dart';

abstract class NativeGateway {
  Future<Map<String, dynamic>> bootstrap();
  Stream<Map<String, dynamic>> get events;
  Future<void> action(String action,
      {String? value, String? zone, bool? enabled});
  Future<void> save(String value);
  void onHome(void Function() callback);
}

class AndroidGateway implements NativeGateway {
  static const methods = MethodChannel('xyz.i4o.uni.launcher/platform');
  static const eventChannel = EventChannel('xyz.i4o.uni.launcher/events');
  @override
  Future<Map<String, dynamic>> bootstrap() async => Map<String, dynamic>.from(
      jsonDecode(await methods.invokeMethod<String>('snapshot') ?? '{}'));
  @override
  Stream<Map<String, dynamic>> get events => eventChannel
      .receiveBroadcastStream()
      .map((value) => Map<String, dynamic>.from(jsonDecode(value as String)));
  @override
  Future<void> action(String action,
      {String? value, String? zone, bool? enabled}) async {
    await methods.invokeMethod(
        'action',
        jsonEncode({
          'action': action,
          if (value != null) 'value': value,
          if (zone != null) 'zone': zone,
          if (enabled != null) 'enabled': enabled
        }));
  }

  @override
  Future<void> save(String value) async {
    if (await methods.invokeMethod<bool>('saveDesign', value) != true)
      throw StateError('保存未完成');
  }

  @override
  void onHome(void Function() callback) {
    methods.setMethodCallHandler((call) async {
      if (call.method == 'home') callback();
    });
  }
}
