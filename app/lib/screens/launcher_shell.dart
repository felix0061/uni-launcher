import 'dart:convert';
import 'package:flutter/material.dart';
import '../platform/native_gateway.dart';
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
            // The car's decor already reserves the OEM control bar. Its inset
            // reports fluctuate when an ActivityView gains focus; never apply
            // that inset a second time to the desktop or move the dock for it.
            resizeToAvoidBottomInset: false,
            body: SceneBackground(
              child: SafeArea(
                  top: false,
                  bottom: false,
                  child: LayoutBuilder(builder: (context, box) {
                    final scale = box.maxWidth / Design.canvasWidth;
                    final nativeHeight =
                        (controller.native.value['viewportHeightPx'] as num?)
                            ?.toDouble();
                    final height = nativeHeight != null && nativeHeight > 0
                        ? (nativeHeight /
                                MediaQuery.devicePixelRatioOf(context))
                            .clamp(0.0, box.maxHeight)
                        : box.maxHeight;
                    if (controller.gateway is AndroidGateway) {
                      final metrics = jsonEncode({
                        'width': box.maxWidth,
                        'maxHeight': box.maxHeight,
                        'height': height,
                        'nativeHeightPx': nativeHeight,
                        'dpr': MediaQuery.devicePixelRatioOf(context),
                        'page': controller.page,
                        'settings': controller.settings
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        AndroidGateway.methods
                            .invokeMethod<void>('viewport', metrics)
                            .catchError((Object _) {});
                      });
                    }
                    return Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                            width: box.maxWidth,
                            height: height,
                            child: FittedBox(
                                fit: BoxFit.fill,
                                child: SizedBox(
                                    width: Design.canvasWidth,
                                    height: height / scale,
                                    child: Column(children: [
                                      Header(controller: controller),
                                      Expanded(
                                          child: IndexedStack(
                                              index:
                                                  controller.settings ? 1 : 0,
                                              children: [
                                            Desktop(controller: controller),
                                            controller.settings
                                                ? SettingsScreen(
                                                    controller: controller)
                                                : const SizedBox.shrink(),
                                          ])),
                                      BottomDock(controller: controller),
                                    ])))));
                  })),
            )));
  }
}
