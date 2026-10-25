import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../platform/native_gateway.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';
import '../widgets/bottom_dock.dart';
import '../widgets/dock_window_scope.dart';

/// The same dock, theme, media and vehicle components in a bounded OS overlay.
class GlobalDockApp extends StatefulWidget {
  final LauncherController controller;
  const GlobalDockApp({super.key, required this.controller});
  @override
  State<GlobalDockApp> createState() => _GlobalDockAppState();
}

class _GlobalDockAppState extends State<GlobalDockApp> {
  final navigator = GlobalKey<NavigatorState>();
  bool expanded = false;
  bool resetScheduled = false;
  @override
  void initState() {
    super.initState();
    widget.controller.native.addListener(_nativeChanged);
    widget.controller.beforeExternalLaunch = () async {
      navigator.currentState?.popUntil((r) => r.isFirst);
      await expand(false);
    };
  }

  void _nativeChanged() {
    final dock = widget.controller.native.value['globalDock'];
    if (!expanded ||
        dock is! Map ||
        dock['visible'] != false ||
        resetScheduled) {
      return;
    }
    resetScheduled = true;
    // HOME or an OEM takeover can hide the overlay without a dock button tap.
    // Discard its modal route before the next external application is shown.
    Future<void>.microtask(() async {
      resetScheduled = false;
      if (!mounted) return;
      navigator.currentState?.popUntil((route) => route.isFirst);
      await expand(false);
    });
  }

  Future<void> expand(bool value) async {
    if (expanded == value) return;
    expanded = value;
    if (mounted) setState(() {});
    await AndroidGateway.methods.invokeMethod<void>('overlay-expanded', value);
  }

  @override
  void dispose() {
    widget.controller.native.removeListener(_nativeChanged);
    widget.controller.beforeExternalLaunch = null;
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final style = SurfaceStyle.from(widget.controller.appearance,
              widget.controller.native.value['dark'] == true);
          return DockWindowScope(
              expand: expand,
              child: MaterialApp(
                navigatorKey: navigator,
                debugShowCheckedModeBanner: false,
                theme: launcherTheme(style),
                color: Colors.transparent,
                home: Scaffold(
                  backgroundColor: Colors.transparent,
                  resizeToAvoidBottomInset: false,
                  body: LayoutBuilder(builder: (context, box) {
                    final width = box.maxWidth;
                    final height = width / Design.canvasWidth * Design.px(96);
                    return Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                            width: width,
                            height: height,
                            child: FittedBox(
                                fit: BoxFit.fill,
                                child: SizedBox(
                                    width: Design.canvasWidth,
                                    height: Design.px(96),
                                    child: BottomDock(
                                        controller: widget.controller)))));
                  }),
                ),
              ));
        },
      );
}
