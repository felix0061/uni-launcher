import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';

/// A compact source identity that doubles as the player's launch target.
class MediaSourceBadge extends StatelessWidget {
  final LauncherController controller;
  const MediaSourceBadge({super.key, required this.controller});
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: controller.native,
          builder: (context, state, _) {
            final s = SurfaceStyle.of(context);
            final preferences = state['integrationPreferences'] as Map? ?? {};
            final media = state['media'] as Map? ?? {};
            final preferred = preferences['mediaPackage'];
            final package =
                preferred != null && preferred != 'auto' && preferred != ''
                    ? preferred
                    : media['source'];
            final apps = state['apps'] as List? ?? [];
            final app = apps
                .whereType<Map>()
                .where((a) => a['package'] == package)
                .firstOrNull;
            final icon = app?['iconBytes'] is Uint8List
                ? app!['iconBytes'] as Uint8List
                : null;
            return Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                    key: const ValueKey('media-source-entry'),
                    onPressed: () => controller.command('launch-player'),
                    style: TextButton.styleFrom(
                        foregroundColor: s.muted,
                        padding: EdgeInsets.symmetric(
                            horizontal: Design.px(12), vertical: Design.px(8)),
                        backgroundColor: s.soft),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      ClipRRect(
                          borderRadius:
                              BorderRadius.circular(s.controlRadius * .5),
                          child: SizedBox(
                              width: Design.px(28),
                              height: Design.px(28),
                              child: icon != null
                                  ? Image.memory(icon,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.music_note_outlined))
                                  : const Icon(Icons.music_note_outlined))),
                      SizedBox(width: Design.px(10)),
                      Flexible(
                          child: Text('${app?['label'] ?? package ?? '音乐播放器'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: Design.px(19)))),
                      SizedBox(width: Design.px(10)),
                      Icon(Icons.open_in_new, size: Design.px(17))
                    ])));
          });
}
