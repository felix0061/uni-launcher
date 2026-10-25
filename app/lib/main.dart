import 'package:flutter/material.dart';
import 'controller/launcher_controller.dart';
import 'platform/native_gateway.dart';
import 'launcher_app.dart';
import 'screens/global_dock_app.dart';
import 'screens/global_panel_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = LauncherController(AndroidGateway());
  await controller.initialize();
  runApp(LauncherApp(controller: controller));
}

@pragma('vm:entry-point')
Future<void> globalDockMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = LauncherController(AndroidGateway());
  await controller.initialize();
  runApp(GlobalDockApp(controller: controller));
}

@pragma('vm:entry-point')
Future<void> globalPanelMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = LauncherController(AndroidGateway());
  await controller.initialize();
  runApp(GlobalPanelApp(controller: controller));
}
