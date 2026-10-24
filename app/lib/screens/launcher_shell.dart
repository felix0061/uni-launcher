import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../widgets/desktop.dart';
import '../widgets/scene_background.dart';
import '../theme/design_tokens.dart';
import '../widgets/bottom_dock.dart';
import 'settings_screen.dart';

class LauncherShell extends StatelessWidget {
  final LauncherController controller;
  const LauncherShell({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) controller.back();
        },
        child: Scaffold(
            body: SceneBackground(
          child: SafeArea(
              top: false,
              child: LayoutBuilder(builder: (context, box) {
                final scale = box.maxWidth / Design.canvasWidth;
                return SizedBox.expand(
                    child: FittedBox(
                        fit: BoxFit.fill,
                        child: SizedBox(
                            width: Design.canvasWidth,
                            height: box.maxHeight / scale,
                            child: Column(children: [
                              Header(controller: controller),
                              Expanded(
                                  child: controller.settings
                                      ? SettingsScreen(controller: controller)
                                      : Desktop(controller: controller)),
                              Padding(
                                  padding: EdgeInsets.fromLTRB(Design.px(32), 0,
                                      Design.px(32), Design.px(16)),
                                  child: BottomDock(controller: controller)),
                            ]))));
              })),
        )));
  }
}
