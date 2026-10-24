import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../theme/launcher_theme.dart';
import 'card_content.dart';
import 'glass_surface.dart';

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
            enabled = demo || mapOf(native['vehicle'])['writable'] == true,
            canPlay = demo || media['available'] == true;
        final playing = media['playing'] == true;
        Widget separator() => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
                height: 30, child: VerticalDivider(color: s.edge, width: 1)));
        Widget zone(String id, String label) =>
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconAction(
                  icon: Icons.remove,
                  label: '降低${label}温度',
                  size: 36,
                  onTap:
                      enabled ? () => c.command('temp-down', zone: id) : null),
              TextButton(
                  onPressed: () => showClimatePanel(context, c),
                  child: Text(
                      demo
                          ? '${(climate[id] as num? ?? 22.5).toStringAsFixed(1)}°'
                          : '—°',
                      style: TextStyle(fontSize: 24, color: s.text))),
              IconAction(
                  icon: Icons.add,
                  label: '升高${label}温度',
                  size: 36,
                  onTap: enabled ? () => c.command('temp-up', zone: id) : null)
            ]);
        return SizedBox(
            key: const ValueKey('bottom-dock'),
            height: 80,
            child: GlassSurface(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  IconAction(
                      key: const ValueKey('home'),
                      icon: Icons.home_outlined,
                      label: '首页，长按进入桌面设置',
                      active: true,
                      onTap: c.home,
                      onLongPress: c.openSettings),
                  const SizedBox(width: 8),
                  IconAction(
                      key: const ValueKey('all-apps'),
                      icon: Icons.apps,
                      label: '全部应用',
                      onTap: () => showAppsPanel(context, c)),
                  separator(),
                  zone('left', '主驾'),
                  IconAction(
                      key: const ValueKey('climate'),
                      icon: Icons.air,
                      label: '空调面板',
                      active: demo,
                      onTap: () => showClimatePanel(context, c)),
                  zone('right', '副驾'),
                  IconAction(
                      icon: Icons.power_settings_new,
                      label: '空调开关',
                      onTap: enabled ? () => c.command('climate-power') : null,
                      active: demo && climate['power'] == true),
                  separator(),
                  IconAction(
                      icon: Icons.skip_previous_outlined,
                      label: '上一首',
                      onTap: canPlay ? () => c.command('previous') : null),
                  IconAction(
                      key: const ValueKey('play-pause'),
                      icon: playing ? Icons.pause : Icons.play_arrow,
                      label: playing ? '暂停' : '播放',
                      onTap: canPlay ? () => c.command('toggle-play') : null,
                      active: true),
                  IconAction(
                      icon: Icons.skip_next_outlined,
                      label: '下一首',
                      onTap: canPlay ? () => c.command('next') : null),
                  const SizedBox(width: 14),
                  Expanded(
                      child: InkWell(
                          key: const ValueKey('music-info'),
                          onTap: () => showMediaPanel(context, c),
                          child: Row(children: [
                            SizedBox(
                                width: 48,
                                height: 48,
                                child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(s.radius * .6),
                                    child: demo
                                        ? const CustomPaint(painter: CoastArt())
                                        : Icon(Icons.music_note_outlined,
                                            color: s.accent, size: 32))),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      '${media['title'] ?? (demo ? '向海而行' : '暂无播放')}',
                                      style: const TextStyle(fontSize: 20),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 5),
                                  Text('${media['artist'] ?? '等待媒体会话'}',
                                      style: TextStyle(
                                          fontSize: 14, color: s.muted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)
                                ]))
                          ]))),
                  separator(),
                  IconAction(
                      key: const ValueKey('vehicle'),
                      icon: Icons.directions_car_outlined,
                      label: '车辆信息',
                      onTap: () => showVehiclePanel(context, c)),
                  const SizedBox(width: 10),
                  IconAction(
                      key: const ValueKey('camera'),
                      icon: Icons.surround_sound_outlined,
                      label: '360 影像',
                      onTap: () => showCameraPanel(context, c)),
                ])));
      });
}

Future<void> showClimatePanel(BuildContext context, LauncherController c) =>
    showDialog(
        context: context,
        builder: (context) => ValueListenableBuilder<Map<String, dynamic>>(
            valueListenable: c.native,
            builder: (context, n, _) {
              final demo = n['demo'] == true,
                  enabled = demo || mapOf(n['vehicle'])['writable'] == true,
                  climate = mapOf(n['climate']);
              return Dialog(
                  backgroundColor: Colors.transparent,
                  child: SizedBox(
                      width: 900,
                      height: 520,
                      child: GlassSurface(
                          child: Column(children: [
                        Row(children: [
                          const Text('座舱舒适', style: TextStyle(fontSize: 30)),
                          const Spacer(),
                          Text(demo ? '模拟演示 · 不控制车辆' : '原车空调待接入'),
                          IconAction(
                              icon: Icons.close,
                              label: '关闭空调',
                              onTap: () => Navigator.pop(context))
                        ]),
                        const Spacer(),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (final zone in ['left', 'right'])
                                Column(children: [
                                  Text(zone == 'left' ? '主驾' : '副驾'),
                                  const SizedBox(height: 18),
                                  Row(children: [
                                    IconAction(
                                        icon: Icons.remove,
                                        label: '降低温度',
                                        onTap: enabled
                                            ? () => c.command('temp-down',
                                                zone: zone)
                                            : null),
                                    Text(
                                        demo
                                            ? '${(climate[zone] as num? ?? 22.5).toStringAsFixed(1)}°'
                                            : '—°',
                                        style: const TextStyle(fontSize: 48)),
                                    IconAction(
                                        icon: Icons.add,
                                        label: '提高温度',
                                        onTap: enabled
                                            ? () =>
                                                c.command('temp-up', zone: zone)
                                            : null)
                                  ])
                                ])
                            ]),
                        const SizedBox(height: 26),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.air),
                              const SizedBox(width: 20),
                              const Text('风量'),
                              IconAction(
                                  icon: Icons.remove,
                                  label: '降低风量',
                                  onTap: enabled
                                      ? () => c.command('fan-down')
                                      : null),
                              Text(demo ? '${climate['fan'] ?? 3}' : '—',
                                  style: const TextStyle(fontSize: 24)),
                              IconAction(
                                  icon: Icons.add,
                                  label: '提高风量',
                                  onTap: enabled
                                      ? () => c.command('fan-up')
                                      : null)
                            ]),
                        const SizedBox(height: 18),
                        Wrap(spacing: 16, children: [
                          for (final mode in ['auto', 'ac', 'sync', 'recirc'])
                            FilterChip(
                                selected: demo && climate[mode] == true,
                                onSelected: enabled
                                    ? (_) =>
                                        c.command('climate-mode', value: mode)
                                    : null,
                                label: Text({
                                  'auto': 'AUTO',
                                  'ac': 'A/C',
                                  'sync': '双区同步',
                                  'recirc': '内循环'
                                }[mode]!))
                        ]),
                        const Spacer(),
                        TextButton(
                            onPressed: () =>
                                c.command('open-official', value: 'climate'),
                            child: const Text('打开原车空调'))
                      ]))));
            }));

Future<void> showVehiclePanel(BuildContext context, LauncherController c) =>
    showDialog(
        context: context,
        builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: SizedBox(
                width: 700,
                height: 540,
                child: GlassSurface(
                    child: Column(children: [
                  Row(children: [
                    const Text('车辆信息', style: TextStyle(fontSize: 30)),
                    const Spacer(),
                    IconAction(
                        icon: Icons.close,
                        label: '关闭车辆信息',
                        onTap: () => Navigator.pop(context))
                  ]),
                  const Expanded(child: TireDiagram()),
                  const Text('等待原车数据'),
                  TextButton(
                      onPressed: () =>
                          c.command('open-official', value: 'vehicle'),
                      child: const Text('打开原车车辆应用'))
                ])))));
Future<void> showCameraPanel(BuildContext context, LauncherController c) =>
    showDialog(
        context: context,
        builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: SizedBox(
                width: 700,
                height: 430,
                child: GlassSurface(
                    child: Column(children: [
                  Row(children: [
                    const Text('360 影像', style: TextStyle(fontSize: 30)),
                    const Spacer(),
                    IconAction(
                        icon: Icons.close,
                        label: '关闭影像面板',
                        onTap: () => Navigator.pop(context))
                  ]),
                  const Spacer(),
                  Icon(Icons.surround_sound_outlined,
                      size: 64, color: SurfaceStyle.of(context).accent),
                  const SizedBox(height: 20),
                  const Text('由原车全景影像服务提供画面'),
                  const Spacer(),
                  FilledButton.tonalIcon(
                      onPressed: () =>
                          c.command('open-official', value: 'camera'),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('打开原车 360'))
                ])))));
