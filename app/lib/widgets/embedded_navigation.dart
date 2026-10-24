import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import '../controller/launcher_controller.dart';
import '../theme/launcher_theme.dart';
import '../theme/design_tokens.dart';
import 'glass_surface.dart';
import 'uni_icon.dart';

/// Desktop preview must never start a second map instance.
class EmbeddedContentPolicy extends InheritedWidget {
  final bool enabled;
  const EmbeddedContentPolicy(
      {super.key, required this.enabled, required super.child});
  static bool allowed(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<EmbeddedContentPolicy>()?.enabled ??
      true;
  @override
  bool updateShouldNotify(EmbeddedContentPolicy old) => old.enabled != enabled;
}

class EmbeddedNavigationCard extends StatefulWidget {
  final LauncherController controller;
  final Map<String, dynamic> navigation;
  const EmbeddedNavigationCard(
      {super.key, required this.controller, required this.navigation});
  @override
  State<EmbeddedNavigationCard> createState() => _EmbeddedNavigationCardState();
}

class _EmbeddedNavigationCardState extends State<EmbeddedNavigationCard> {
  MethodChannel? channel;
  Map<String, dynamic> status = {};
  String get package => '${widget.navigation['package'] ?? ''}';
  @override
  void didUpdateWidget(EmbeddedNavigationCard old) {
    super.didUpdateWidget(old);
    if ('${old.navigation['package'] ?? ''}' != package ||
        old.navigation['canEmbed'] != widget.navigation['canEmbed']) {
      channel?.setMethodCallHandler(null);
      channel = null;
      status = {};
    }
  }

  @override
  void dispose() {
    channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void connect(int id) {
    final current = MethodChannel('xyz.i4o.uni.launcher/map/$id');
    channel = current;
    channel!.setMethodCallHandler((call) async {
      if (mounted &&
          channel == current &&
          call.method == 'status' &&
          call.arguments is Map)
        setState(() => status = Map<String, dynamic>.from(call.arguments));
    });
    channel!.invokeMapMethod<String, dynamic>('status').then((value) {
      if (mounted && channel == current && value != null)
        setState(() => status = value);
    }).catchError((Object error) {
      if (mounted && channel == current)
        setState(() => status = {'phase': 'failed', 'reason': '地图连接已断开'});
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context), c = widget.controller;
    final allowed = EmbeddedContentPolicy.allowed(context);
    final canEmbed = widget.navigation['canEmbed'] == true &&
        allowed &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android;
    final failed =
        status['phase'] == 'failed' || status['phase'] == 'unavailable';
    return Column(children: [
      Padding(
          padding: EdgeInsets.symmetric(
              horizontal: Design.px(24), vertical: Design.px(14)),
          child: Row(children: [
            UniIcon('nav', color: s.accent, size: Design.px(25)),
            SizedBox(width: Design.px(12)),
            Text('${widget.navigation['label'] ?? '高德地图'}',
                style: TextStyle(fontSize: Design.px(23))),
            const Spacer(),
            IconAction(
                icon: Icons.open_in_full,
                label: '全屏打开导航',
                size: Design.px(38),
                onTap: () => c.command('launch-navigation')),
          ])),
      Expanded(
          child: canEmbed && !failed
              ? Stack(children: [
                  Positioned.fill(
                      child: PlatformViewLink(
                          key: ValueKey('native-map-$package'),
                          viewType: 'xyz.i4o.uni.launcher/navigation',
                          surfaceFactory: (context, controller) =>
                              AndroidViewSurface(
                                  controller:
                                      controller as AndroidViewController,
                                  gestureRecognizers: c.editing
                                      ? {}
                                      : {
                                          Factory<OneSequenceGestureRecognizer>(
                                              () => EagerGestureRecognizer())
                                        },
                                  hitTestBehavior: c.editing
                                      ? PlatformViewHitTestBehavior.transparent
                                      : PlatformViewHitTestBehavior.opaque),
                          onCreatePlatformView: (params) {
                            final controller =
                                PlatformViewsService.initExpensiveAndroidView(
                                    id: params.id,
                                    viewType: 'xyz.i4o.uni.launcher/navigation',
                                    layoutDirection: TextDirection.ltr);
                            controller.addOnPlatformViewCreatedListener(
                                params.onPlatformViewCreated);
                            controller
                                .addOnPlatformViewCreatedListener(connect);
                            controller.create();
                            return controller;
                          })),
                  if (status['ready'] != true)
                    const Center(child: CircularProgressIndicator()),
                ])
              : Center(
                  child: Padding(
                      padding: EdgeInsets.all(Design.px(30)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        UniIcon('nav', size: Design.px(60), color: s.accent),
                        SizedBox(height: Design.px(20)),
                        Text(
                            !allowed
                                ? '地图卡片预览'
                                : (!canEmbed
                                        ? widget.navigation['reason']
                                            ?.toString()
                                        : status['reason']?.toString()) ??
                                    '等待导航应用',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: Design.px(23), color: s.muted)),
                        SizedBox(height: Design.px(24)),
                        if (allowed)
                          FilledButton(
                              onPressed: () => c.command('launch-navigation'),
                              child: const Text('全屏打开导航')),
                        if (failed && allowed)
                          TextButton(
                              onPressed: () => setState(() => status = {}),
                              child: const Text('重新尝试嵌入')),
                      ]))))
    ]);
  }
}
