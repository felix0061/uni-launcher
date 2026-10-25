import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';
import 'card_content.dart' show mapOf;

/// System-task actions use the same Material components, shape and state
/// overlays as every other desktop button. The actual cleanup stays with OEM.
class RecentsFooter extends StatelessWidget {
  final LauncherController controller;
  const RecentsFooter({super.key, required this.controller});
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: controller.native,
          builder: (context, state, _) {
            final s = SurfaceStyle.of(context);
            final memory = mapOf(mapOf(state['systemStatus'])['memory']);
            final total = memory['totalBytes'] as num?,
                used = memory['usedBytes'] as num?;
            String gib(num bytes) =>
                (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2);
            return SizedBox.expand(
                child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                        width: Design.canvasWidth,
                        height: Design.px(120),
                        child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: Design.px(40),
                                vertical: Design.px(24)),
                            child: Row(children: [
                              SizedBox(
                                  width: Design.px(272),
                                  height: Design.px(64),
                                  child: OutlinedButton.icon(
                                      key: const ValueKey(
                                          'system-recents-clear'),
                                      onPressed: mapOf(state['globalDock'])[
                                                      'recentsClearSupported'] ==
                                                  true &&
                                              mapOf(state['globalDock'])[
                                                      'recentsReady'] ==
                                                  true
                                          ? () => controller
                                              .command('clear-system-recents')
                                          : null,
                                      icon: const Icon(
                                          Icons.cleaning_services_outlined),
                                      label: const Text('一键清理'))),
                              const Spacer(),
                              if (total != null && used != null)
                                Text('已用 ${gib(used)} GB / ${gib(total)} GB',
                                    style: TextStyle(
                                        fontSize: Design.px(22),
                                        color: s.muted)),
                            ])))));
          });
}
