import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../controller/launcher_controller.dart';
import '../model/card_layout.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';
import 'clock_card.dart';
import 'glass_surface.dart';
import 'launcher_dialog.dart';
import 'uni_icon.dart';
import 'lyrics_view.dart';
import 'media_progress.dart';
import 'embedded_navigation.dart';
import 'media_artwork.dart';
import 'weather_icon.dart';
import '../model/weather_condition.dart';
import '../model/vehicle_data.dart';

part 'card_content_music.dart';
part 'card_content_navigation.dart';
part 'card_content_oem.dart';
part 'card_content_panels.dart';

Map<String, dynamic> mapOf(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};

// Retained for callers using the original public IconData API.
IconData cardIcon(String type) =>
    const <String, IconData>{
      'nav': Icons.navigation_outlined,
      'music': Icons.music_note_outlined,
      'weather': Icons.cloud_outlined,
      'calendar': Icons.calendar_month_outlined,
      'member': Icons.person_outline,
      'cleanup': Icons.cleaning_services_outlined,
      'tpms': Icons.tire_repair_outlined,
      'air': Icons.air,
      'ride': Icons.local_taxi_outlined,
      'clock': Icons.schedule,
      'shortcuts': Icons.apps,
      'vehicle': Icons.directions_car_outlined,
    }[type] ??
    Icons.apps;

String cardSymbol(String type) =>
    const {
      'weather': 'cloud',
      'calendar': 'calendar',
      'member': 'user',
      'cleanup': 'broom',
      'tpms': 'tire',
      'air': 'air',
      'vehicle': 'car',
      'shortcuts': 'apps',
    }[type] ??
    type;

class CardContent extends StatelessWidget {
  final LauncherCard card;
  final LauncherController controller;
  const CardContent({super.key, required this.card, required this.controller});
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<Map<String, dynamic>>(
        valueListenable: controller.native,
        builder: (context, native, _) => switch (card.type) {
          'nav' => native['navigation'] is Map
              ? EmbeddedNavigationCard(
                  controller: controller,
                  navigation: mapOf(native['navigation']))
              : native['demo'] == true
                  ? const _NavigationDemo()
                  : _NavigationWaiting(card: card, controller: controller),
          'music' =>
            _MusicCard(card: card, controller: controller, state: native),
          'weather' => _WeatherCard(
              card: card,
              demo: native['demo'] == true,
              native: native,
              editing: controller.editing),
          'clock' => ClockCard(title: card.title),
          'shortcuts' => _ShortcutCard(card: card, controller: controller),
          _ => _OemCard(
              card: card, controller: controller, demo: native['demo'] == true),
        },
      );
}

/// Only undersized grids use a smaller fitted canvas. Default sizes retain the
/// exact design measurements; even the 64 px edit strip leaves no overflowing row.
class _CardCanvas extends StatelessWidget {
  final Widget child;
  final double minWidth, minHeight;
  final bool padded;
  const _CardCanvas(
      {required this.child,
      this.minWidth = 340,
      this.minHeight = 240,
      this.padded = true});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final width = math.max(box.maxWidth, Design.px(minWidth));
        final height = math.max(box.maxHeight, Design.px(minHeight));
        final content = padded
            ? Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: Design.px(30), vertical: Design.px(28)),
                child: child)
            : child;
        if (width == box.maxWidth && height == box.maxHeight) return content;
        return FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: SizedBox(width: width, height: height, child: content));
      });
}

class _Heading extends StatelessWidget {
  final String title, source, symbol;
  const _Heading(this.title, this.source, this.symbol);
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return SizedBox(
        height: Design.px(32),
        child: Row(children: [
          UniIcon(symbol, size: Design.px(27), color: s.accent),
          SizedBox(width: Design.px(12)),
          Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: Design.px(25), height: 1.2))),
          SizedBox(width: Design.px(14)),
          Flexible(
              child: Text(source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: Design.px(16), height: 1.2, color: s.muted))),
        ]));
  }
}

class _OpenCardButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool arrowFirst, compact;
  const _OpenCardButton(this.label,
      {required this.onTap, this.arrowFirst = false, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    final arrow = UniIcon('arrow-right', size: Design.px(22), color: s.text);
    return SizedBox(
        width: double.infinity,
        height: Design.px(compact ? 45 : 56),
        child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
                minimumSize: Size.zero,
                padding: EdgeInsets.symmetric(horizontal: Design.px(12)),
                textStyle: TextStyle(fontSize: Design.px(compact ? 18 : 20))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (arrowFirst) ...[arrow, SizedBox(width: Design.px(10))],
              Flexible(
                  child: Text(label,
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (!arrowFirst) ...[SizedBox(width: Design.px(10)), arrow],
            ])));
  }
}
