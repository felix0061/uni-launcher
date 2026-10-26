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
import 'navigation_app_picker.dart';
import 'page_transition.dart';

/// Desktop preview must never start a second map instance.
class EmbeddedContentPolicy extends InheritedWidget {
  final bool enabled;
  final bool visible;
  const EmbeddedContentPolicy(
      {super.key,
      required this.enabled,
      this.visible = true,
      required super.child});
  static bool allowed(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<EmbeddedContentPolicy>()?.enabled ??
      true;
  static bool visibleOf(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<EmbeddedContentPolicy>()?.visible ??
      true;
  @override
  bool updateShouldNotify(EmbeddedContentPolicy old) =>
      old.enabled != enabled || old.visible != visible;
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
  bool desiredVisible = true;
  bool? sentVisible;
  Map<String, dynamic> status = {};
  String get package => '${widget.navigation['package'] ?? ''}';
  @override
  void didUpdateWidget(EmbeddedNavigationCard old) {
    super.didUpdateWidget(old);
    if ('${old.navigation['package'] ?? ''}' != package ||
        old.navigation['canEmbed'] != widget.navigation['canEmbed']) {
      channel?.setMethodCallHandler(null);
      channel = null;
      sentVisible = null;
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
    sentVisible = null;
    syncVisibility(desiredVisible);
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

  void syncVisibility(bool visible) {
    desiredVisible = visible;
    final current = channel;
    if (current == null ||
        (sentVisible == visible && !(visible && status['phase'] == 'paused')))
      return;
    sentVisible = visible;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && channel == current && desiredVisible == visible) {
        current
            .invokeMethod<void>('visible', visible)
            .catchError((Object _) {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context), c = widget.controller;
    final displayName = c.appName(
        {'package': package, 'label': widget.navigation['label'] ?? '高德地图'});
    final allowed = EmbeddedContentPolicy.allowed(context);
    final moving = DesktopMotionScope.movingOf(context);
    // Offstage alone does not hide Android 9's independently composited SurfaceView.
    syncVisibility(allowed &&
        EmbeddedContentPolicy.visibleOf(context) &&
        !moving &&
        !c.settings &&
        (ModalRoute.of(context)?.isCurrent ?? true));
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
            Expanded(
                child: InkWell(
                    key: const ValueKey('nav-title-open'),
                    onTap: () => c.command('launch-navigation'),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(
                          child: Text(displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: Design.px(23)))),
                    ]))),
            IconAction(
                key: const ValueKey('nav-app-picker'),
                icon: Icons.swap_horiz,
                label: '选择导航应用',
                size: Design.px(38),
                onTap: () => showNavigationPicker(context, c)),
            IconAction(
                icon: Icons.open_in_full,
                label: '全屏打开导航',
                size: Design.px(38),
                onTap: () => c.command('launch-navigation')),
          ])),
      Expanded(
          child: canEmbed && !failed
              ? Stack(children: [
                  // Consume the cached texture while live native content covers
                  // it, so its producer cannot fill an unread buffer queue.
                  if (status['previewTextureId'] is num)
                    Positioned.fill(
                        key: const ValueKey('map-preview-background'),
                        child: Texture(
                            textureId:
                                (status['previewTextureId'] as num).toInt())),
                  Positioned.fill(
                      key: const ValueKey('map-native-surface'),
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
                  if (status['ready'] != true || moving)
                    Positioned.fill(
                        key: const ValueKey('map-restoring-preview'),
                        child: status['previewTextureId'] is num
                            ? Texture(
                                textureId:
                                    (status['previewTextureId'] as num).toInt())
                            : ColoredBox(
                                color: s.strong.withValues(alpha: 1),
                                child: const Center(
                                    child: CircularProgressIndicator()))),
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
