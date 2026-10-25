import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';
import 'card_content.dart';
import 'glass_surface.dart';
import 'launcher_dialog.dart';
import 'uni_icon.dart';
import 'lyrics_view.dart';
import 'media_artwork.dart';
import '../model/vehicle_data.dart';
import 'vehicle_readout.dart';
import 'climate_panel.dart';
export 'climate_panel.dart' show showClimatePanel;

class BottomDock extends StatelessWidget {
  final LauncherController controller;
  const BottomDock({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<
          Map<String, dynamic>>(
      valueListenable: controller.native,
      builder: (context, native, _) {
        final c = controller,
            s = SurfaceStyle.of(context),
            demo = native['demo'] == true,
            climate = mapOf(native['climate']),
            media = mapOf(native['media']),
            canPlay = demo || media['available'] == true,
            playing = media['playing'] == true;
        Widget gap() => SizedBox(width: Design.px(20));
        Widget separator() => SizedBox(
            height: Design.px(34),
            width: Design.px(1),
            child: ColoredBox(color: s.edge));
        Widget action(
                String key, IconData icon, String label, VoidCallback? tap,
                {bool active = false,
                bool solid = false,
                bool soft = false,
                double width = 64}) =>
            IconAction(
                key: ValueKey(key),
                icon: icon,
                label: label,
                size: Design.px(width),
                iconSize: Design.px(29),
                onTap: tap,
                active: active,
                solid: solid,
                soft: soft);
        Widget zone(String id, String label) =>
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconAction(
                  icon: Icons.remove,
                  label: '降低${label}温度',
                  size: Design.px(40),
                  iconSize: Design.px(21),
                  foregroundColor: s.muted,
                  onTap: climateWritable(native, id)
                      ? () => c.command('temp-down', zone: id)
                      : null),
              SizedBox(
                  width: Design.px(88),
                  height: Design.px(64),
                  child: InkWell(
                      onTap: () => showClimatePanel(context, c),
                      child: Center(
                          child: Text(
                              demo
                                  ? '${(climate[id] as num? ?? 22.5).toStringAsFixed(1)}°'
                                  : '${VehicleField.fromNative(native, id).display()}°',
                              style: TextStyle(fontSize: Design.px(32)))))),
              IconAction(
                  icon: Icons.add,
                  label: '升高${label}温度',
                  size: Design.px(40),
                  iconSize: Design.px(21),
                  foregroundColor: s.muted,
                  onTap: climateWritable(native, id)
                      ? () => c.command('temp-up', zone: id)
                      : null)
            ]);
        return SizedBox(
            key: const ValueKey('bottom-dock'),
            height: Design.px(96),
            child: GlassSurface(
                radius: 0,
                shadow: false,
                tone: SurfaceTone.strong,
                padding: EdgeInsets.symmetric(
                    horizontal: Design.px(52), vertical: Design.px(12)),
                child: Row(children: [
                  SizedBox(
                      width: Design.px(142),
                      child: Row(children: [
                        IconAction(
                            key: const ValueKey('home'),
                            icon: Icons.home_outlined,
                            label: '首页，长按进入桌面设置',
                            size: Design.px(64),
                            iconSize: Design.px(29),
                            active: true,
                            soft: true,
                            onTap: c.home,
                            onLongPress: c.openSettings),
                        SizedBox(width: Design.px(14)),
                        action('all-apps', Icons.apps, '全部应用',
                            () => showAppsPanel(context, c))
                      ])),
                  gap(),
                  separator(),
                  gap(),
                  SizedBox(
                      width: Design.px(480),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            zone('left', '主驾'),
                            action('climate', Icons.air, '空调与座椅',
                                () => showClimatePanel(context, c),
                                active: true, width: 56),
                            zone('right', '副驾'),
                            action(
                                'climate-power',
                                Icons.power_settings_new,
                                '空调开关',
                                climateWritable(native, 'power')
                                    ? () => c.command('climate-power')
                                    : null,
                                active: climate['power'] == true,
                                width: 56)
                          ])),
                  gap(),
                  separator(),
                  gap(),
                  SizedBox(
                      width: Design.px(194),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            action(
                                'previous',
                                Icons.skip_previous_outlined,
                                '上一首',
                                canPlay &&
                                        (demo || media['canPrevious'] == true)
                                    ? () => c.command('previous')
                                    : null,
                                width: 60),
                            action(
                                'play-pause',
                                playing ? Icons.pause : Icons.play_arrow,
                                playing ? '暂停' : '播放',
                                canPlay && (demo || media['canToggle'] == true)
                                    ? () => c.command('toggle-play')
                                    : null,
                                solid: true,
                                width: 58),
                            action(
                                'next',
                                Icons.skip_next_outlined,
                                '下一首',
                                canPlay && (demo || media['canNext'] == true)
                                    ? () => c.command('next')
                                    : null,
                                width: 60)
                          ])),
                  gap(),
                  Expanded(
                      child: InkWell(
                          key: const ValueKey('music-info'),
                          onTap: () => showMediaPanel(context, c),
                          child: Row(children: [
                            ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(s.radius * .5),
                                child: SizedBox(
                                    width: Design.px(60),
                                    height: Design.px(60),
                                    child: MediaArtwork(
                                        media: media, demo: demo))),
                            SizedBox(width: Design.px(16)),
                            Expanded(
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('${media['title'] ?? '暂无播放'}',
                                      style: TextStyle(
                                          fontSize: Design.px(24),
                                          fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  SizedBox(height: Design.px(6)),
                                  if ((media['lyrics'] as String? ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    LyricsView(
                                        media: media,
                                        compact: true,
                                        textAlign: TextAlign.start)
                                  else
                                    Text(
                                        '${media['artist'] ?? '等待媒体会话'}${demo ? ' · 原车媒体中心' : ''}',
                                        style: TextStyle(
                                            fontSize: Design.px(17),
                                            color: s.muted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis)
                                ]))
                          ]))),
                  gap(),
                  separator(),
                  gap(),
                  action('vehicle', Icons.directions_car_outlined, '车辆信息',
                      () => showVehiclePanel(context, c)),
                  gap(),
                  action('camera', Icons.surround_sound_outlined, '360 影像',
                      () => showCameraPanel(context, c))
                ])));
      });
}

Future<void> showVehiclePanel(BuildContext context, LauncherController c) =>
    showLauncherSheet<void>(context,
        title: '车辆信息',
        subtitle: '原车数据 · 只读',
        closeLabel: '关闭车辆信息',
        width: Design.px(900),
        height: Design.px(780),
        builder: (context) => ValueListenableBuilder<Map<String, dynamic>>(
            valueListenable: c.native,
            builder: (context, n, _) =>
                VehicleReadout(controller: c, native: n)));
Future<void> showCameraPanel(BuildContext context, LauncherController c) =>
    showLauncherSheet<void>(context,
        title: '360 影像',
        subtitle: '原车全景影像入口',
        closeLabel: '关闭影像面板',
        width: Design.px(1320), builder: (context) {
      final s = SurfaceStyle.of(context);
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            height: Design.px(520),
            decoration: BoxDecoration(
                color: const Color(0x6607151D),
                borderRadius: BorderRadius.circular(s.radius)),
            alignment: Alignment.center,
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              UniIcon('camera', size: Design.px(86), color: s.accent),
              SizedBox(height: Design.px(28)),
              Text('等待车辆影像', style: TextStyle(fontSize: Design.px(36))),
              SizedBox(height: Design.px(18)),
              Text('车辆连接后，由原车影像服务提供画面',
                  style: TextStyle(fontSize: Design.px(22), color: s.muted))
            ])),
        SizedBox(height: Design.px(20)),
        OutlinedButton.icon(
            onPressed: () => c.command('open-official', value: 'camera'),
            icon: const UniIcon('arrow-right'),
            label: const Text('打开原车 360'))
      ]);
    });
