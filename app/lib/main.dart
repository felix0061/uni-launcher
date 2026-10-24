import 'package:flutter/material.dart';
import 'controller/launcher_controller.dart';
import 'platform/native_gateway.dart';
import 'launcher_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = LauncherController(AndroidGateway());
  await controller.initialize();
  runApp(LauncherApp(controller: controller));
}
