import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';
import 'glass_surface.dart';

/// One glass sheet and one design-coordinate system for every desktop overlay.
Future<T?> showLauncherSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  String closeLabel = '关闭面板',
  required double width,
  double? height,
  required WidgetBuilder builder,
}) =>
    showGeneralDialog<T>(
        context: context,
        barrierDismissible: true,
        barrierLabel: closeLabel,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, _, __) => LauncherSheet(
            title: title,
            subtitle: subtitle,
            closeLabel: closeLabel,
            width: width,
            height: height,
            child: Builder(builder: builder)));

class LauncherSheet extends StatelessWidget {
  final String title, closeLabel;
  final String? subtitle;
  final double width;
  final double? height;
  final Widget child;
  const LauncherSheet(
      {super.key,
      required this.title,
      required this.closeLabel,
      required this.width,
      this.subtitle,
      this.height,
      required this.child});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return Material(
        type: MaterialType.transparency,
        child: Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: ColoredBox(
                      color: s.dark
                          ? const Color(0x8007151D)
                          : const Color(0x3361716B)))),
          if (s.glass)
            Positioned.fill(
                child: IgnorePointer(
                    child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: const SizedBox.expand()))),
          Positioned.fill(
              child: SafeArea(child: LayoutBuilder(builder: (context, box) {
            final scale = box.maxWidth / Design.canvasWidth;
            final canvasHeight = box.maxHeight / scale;
            return SizedBox.expand(
                child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                        width: Design.canvasWidth,
                        height: canvasHeight,
                        child: Center(
                            child: ConstrainedBox(
                                constraints: BoxConstraints(
                                    maxWidth: width,
                                    maxHeight: math.max(
                                        120, canvasHeight - Design.px(64))),
                                child: SizedBox(
                                    width: width,
                                    height: height,
                                    child: GlassSurface(
                                        tone: SurfaceTone.strong,
                                        padding: EdgeInsets.symmetric(
                                            horizontal: Design.px(40),
                                            vertical: Design.px(34)),
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Row(children: [
                                                Expanded(
                                                    child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                      Text(title,
                                                          style: TextStyle(
                                                              fontSize:
                                                                  Design.px(34),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500)),
                                                      if (subtitle != null) ...[
                                                        SizedBox(
                                                            height:
                                                                Design.px(12)),
                                                        Text(subtitle!,
                                                            style: TextStyle(
                                                                fontSize:
                                                                    Design.px(
                                                                        20),
                                                                color: s.muted))
                                                      ],
                                                    ])),
                                                IconAction(
                                                    icon: Icons.close,
                                                    label: closeLabel,
                                                    size: Design.px(54),
                                                    iconSize: Design.px(25),
                                                    soft: true,
                                                    onTap: () =>
                                                        Navigator.pop(context))
                                              ]),
                                              SizedBox(height: Design.px(28)),
                                              Flexible(child: child),
                                            ]))))))));
          }))),
        ]));
  }
}
