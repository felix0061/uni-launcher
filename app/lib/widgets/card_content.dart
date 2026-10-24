import 'clock_card.dart';
import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../model/card_layout.dart';
import '../theme/launcher_theme.dart';
import 'glass_surface.dart';

Map<String, dynamic> mapOf(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
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
      'vehicle': Icons.directions_car_outlined
    }[type] ??
    Icons.widgets_outlined;

class CardContent extends StatelessWidget {
  final LauncherCard card;
  final LauncherController controller;
  const CardContent({super.key, required this.card, required this.controller});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<
          Map<String, dynamic>>(
      valueListenable: controller.native,
      builder: (context, native, _) {
        final s = SurfaceStyle.of(context), demo = native['demo'] == true;
        final media = mapOf(native['media']);
        if (card.type == 'nav' && demo)
          return _NavigationDemo(accent: s.accent);
        if (card.type == 'music')
          return Padding(
              padding: const EdgeInsets.all(22),
              child: Column(children: [
                CardHeading(card.title, demo ? '模拟音源' : '媒体会话',
                    Icons.music_note_outlined),
                Expanded(child: LayoutBuilder(builder: (context, box) {
                  final compact = box.maxHeight < 340,
                      tiny = box.maxHeight < 230;
                  return Center(
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                              width: box.maxWidth,
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (!compact)
                                      SizedBox(
                                          width: 158,
                                          height: 158,
                                          child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      s.radius * .8),
                                              child: demo
                                                  ? const CustomPaint(
                                                      painter: CoastArt())
                                                  : ColoredBox(
                                                      color: s.accent
                                                          .withValues(
                                                              alpha: .10),
                                                      child: Icon(
                                                          Icons
                                                              .music_note_outlined,
                                                          size: 74,
                                                          color: s.accent)))),
                                    SizedBox(height: tiny ? 4 : 18),
                                    Text(
                                        '${media['title'] ?? (demo ? '向海而行' : '暂无播放')}',
                                        maxLines: tiny ? 1 : 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: compact ? 24 : 30)),
                                    SizedBox(height: tiny ? 4 : 12),
                                    Text(
                                        '${media['artist'] ?? (demo ? 'Coastline · 晨间驾驶歌单' : '等待媒体会话')}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 17, color: s.muted)),
                                    if (!tiny) const SizedBox(height: 18),
                                    if (!tiny)
                                      TextButton.icon(
                                          onPressed: () => showMediaPanel(
                                              context, controller),
                                          icon: const Icon(Icons.arrow_forward,
                                              size: 20),
                                          label: const Text('播放详情')),
                                  ]))));
                }))
              ]));
        if (card.type == 'weather' && demo)
          return Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CardHeading('杭州', '天气演示', Icons.location_on_outlined),
                    Expanded(
                        child: LayoutBuilder(
                            builder: (context, box) => Row(children: [
                                  Text('24°',
                                      style: TextStyle(
                                          fontSize: (box.maxHeight * .60)
                                              .clamp(28, 56)
                                              .toDouble(),
                                          fontWeight: FontWeight.w300)),
                                  const SizedBox(width: 14),
                                  Text('多云',
                                      style: TextStyle(
                                          color: s.muted, fontSize: 20)),
                                  const Spacer(),
                                  Icon(Icons.cloud_outlined,
                                      color: s.accent,
                                      size: box.maxHeight
                                          .clamp(32, 66)
                                          .toDouble())
                                ]))),
                    Text('原厂天气数据待接入',
                        style: TextStyle(color: s.muted, fontSize: 14))
                  ]));
        if (card.type == 'clock') return ClockCard(title: card.title);
        if (card.type == 'shortcuts')
          return Center(
              child: FilledButton.tonalIcon(
                  onPressed: () => showAppsPanel(context, controller),
                  icon: const Icon(Icons.apps),
                  label: const Text('全部应用')));
        if (card.type == 'tpms' || card.type == 'vehicle')
          return Padding(
              padding: const EdgeInsets.all(22),
              child: Column(children: [
                CardHeading(card.title, '原车车辆信息', Icons.tire_repair_outlined),
                Expanded(child: LayoutBuilder(builder: (context, box) {
                  if (box.maxHeight < 130) {
                    return Center(
                        child: TextButton.icon(
                            onPressed: () => controller
                                .command('official-widget', value: 'tpms'),
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: const Text('等待车辆数据 · 打开原厂卡片')));
                  }
                  return Column(children: [
                    const Expanded(child: TireDiagram()),
                    Text('等待车辆数据',
                        style: TextStyle(color: s.muted, fontSize: 17)),
                    const SizedBox(height: 10),
                    TextButton(
                        onPressed: () => controller.command('official-widget',
                            value: 'tpms'),
                        child: const Text('打开原厂胎压卡片')),
                  ]);
                }))
              ]));
        final spec = specFor(card.type);
        return Padding(
            padding: const EdgeInsets.all(22),
            child: Column(children: [
              CardHeading(card.type == 'weather' ? '天气' : card.title,
                  spec.source, cardIcon(card.type)),
              Expanded(child: LayoutBuilder(builder: (context, box) {
                final small = card.h <= 2 || box.maxHeight < 300,
                    tiny = box.maxHeight < 100;
                return Center(
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                            width: box.maxWidth,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (!small) ...[
                                    Icon(cardIcon(card.type),
                                        size: 52, color: s.accent),
                                    const SizedBox(height: 18)
                                  ],
                                  Text(
                                      card.type == 'member'
                                          ? '账号状态未同步'
                                          : card.type == 'cleanup'
                                              ? '清理信息未同步'
                                              : '等待原车信息',
                                      style: TextStyle(
                                          fontSize: tiny
                                              ? 18
                                              : small
                                                  ? 22
                                                  : 28)),
                                  if (!small) ...[
                                    const SizedBox(height: 12),
                                    Text('保持官方信息来源',
                                        style: TextStyle(
                                            color: s.muted, fontSize: 17)),
                                    const SizedBox(height: 18)
                                  ],
                                  TextButton.icon(
                                      onPressed: () => controller.command(
                                          'official-widget',
                                          value: card.type),
                                      icon: const Icon(Icons.arrow_forward,
                                          size: 18),
                                      label: const Text('打开原厂卡片')),
                                  if (!small)
                                    TextButton(
                                        onPressed: () => controller.command(
                                            'open-official',
                                            value: card.type),
                                        child: const Text('打开原车应用')),
                                ]))));
              }))
            ]));
      });
}

class _NavigationDemo extends StatelessWidget {
  final Color accent;
  const _NavigationDemo({required this.accent});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return Stack(children: [
      Positioned.fill(child: CustomPaint(painter: RoadPainter(accent, s.dark))),
      Positioned(
          top: 22,
          left: 22,
          child: GlassSurface(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(s.radius * .65)),
                    child: Icon(Icons.turn_right,
                        size: 44,
                        color:
                            s.dark ? const Color(0xFF10292C) : Colors.white)),
                const SizedBox(width: 20),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('600 米后右转', style: TextStyle(fontSize: 30)),
                  const SizedBox(height: 8),
                  Text('进入城市大道', style: TextStyle(fontSize: 19, color: s.muted))
                ])
              ]))),
      Positioned(
          bottom: 22,
          left: 22,
          right: 22,
          child: GlassSurface(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('前往 · 城市中心',
                      style: TextStyle(color: s.muted, fontSize: 16)),
                  const SizedBox(height: 10),
                  const Row(children: [
                    Text('10:08 到达', style: TextStyle(fontSize: 30)),
                    SizedBox(width: 18),
                    Text('27 分钟 · 12.6 公里', style: TextStyle(fontSize: 18))
                  ])
                ]),
                const Spacer(),
                Icon(Icons.navigation_outlined, color: accent, size: 32)
              ]))),
      const Positioned(
          top: 22, right: 24, child: Text('N', style: TextStyle(fontSize: 22))),
    ]);
  }
}

class RoadPainter extends CustomPainter {
  final Color accent;
  final bool dark;
  RoadPainter(this.accent, this.dark);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1000, size.height / 700);
    final road = Paint()
      ..color = (dark ? const Color(0xFF8BAAAD) : Colors.white)
          .withValues(alpha: dark ? .15 : .75)
      ..strokeWidth = 13
      ..style = PaintingStyle.stroke;
    for (double x = 120; x < 1000; x += 160) {
      canvas.drawLine(Offset(x, 0), Offset(x, 700), road);
    }
    for (double y = 120; y < 700; y += 160) {
      canvas.drawLine(Offset(0, y), Offset(1000, y), road);
    }
    canvas.drawPath(
        Path()
          ..moveTo(0, 600)
          ..quadraticBezierTo(500, 450, 600, 0),
        road..strokeWidth = 18);
    final route = Path()
      ..moveTo(570, 500)
      ..lineTo(570, 450)
      ..lineTo(720, 450)
      ..lineTo(720, 140)
      ..lineTo(880, 140);
    canvas.drawPath(
        route,
        Paint()
          ..color = accent.withValues(alpha: .22)
          ..strokeWidth = 25
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(
        route,
        Paint()
          ..color = accent
          ..strokeWidth = 11
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(const Offset(570, 500), 25,
        Paint()..color = dark ? const Color(0xFF1C3540) : Colors.white);
    canvas.drawPath(
        Path()
          ..moveTo(570, 482)
          ..lineTo(583, 516)
          ..lineTo(570, 510)
          ..lineTo(557, 516)
          ..close(),
        Paint()..color = accent);
    canvas.drawCircle(const Offset(880, 140), 12, Paint()..color = accent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(RoadPainter old) =>
      old.accent != accent || old.dark != dark;
}

class CoastArt extends CustomPainter {
  const CoastArt();
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = Color(0xFFD3BD97));
    c.drawCircle(Offset(s.width * .76, s.height * .25), s.width * .18,
        Paint()..color = const Color(0xFFF6D59B));
    c.drawPath(
        Path()
          ..moveTo(0, s.height * .60)
          ..quadraticBezierTo(
              s.width * .35, s.height * .27, s.width * .7, s.height * .60)
          ..lineTo(s.width, s.height * .62)
          ..lineTo(s.width, s.height)
          ..lineTo(0, s.height)
          ..close(),
        Paint()..color = const Color(0xFF607F89));
    c.drawPath(
        Path()
          ..moveTo(0, s.height * .77)
          ..quadraticBezierTo(
              s.width * .25, s.height * .46, s.width * .60, s.height * .78)
          ..lineTo(s.width, s.height * .76)
          ..lineTo(s.width, s.height)
          ..lineTo(0, s.height)
          ..close(),
        Paint()..color = const Color(0xFF1F4A5D));
  }

  @override
  bool shouldRepaint(CoastArt old) => false;
}

class TireDiagram extends StatelessWidget {
  const TireDiagram({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return Center(
        child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
                width: 300,
                height: 250,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _values(s, '左前', '左后'),
                      Icon(Icons.directions_car_outlined,
                          size: 90, color: s.accent),
                      _values(s, '右前', '右后')
                    ]))));
  }

  Widget _values(SurfaceStyle s, String a, String b) =>
      Column(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        for (final label in [a, b])
          Column(children: [
            Text(label, style: TextStyle(color: s.muted, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('—', style: TextStyle(fontSize: 32))
          ])
      ]);
}

Future<void> showAppsPanel(BuildContext context, LauncherController c) =>
    showDialog(context: context, builder: (context) => AppPanel(controller: c));
Future<void> showMediaPanel(BuildContext context, LauncherController c) =>
    showDialog(
        context: context, builder: (context) => MediaPanel(controller: c));

class AppPanel extends StatelessWidget {
  final LauncherController controller;
  const AppPanel({super.key, required this.controller});
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: controller.native,
          builder: (context, state, _) {
            final apps = (state['apps'] as List?) ?? [];
            return Dialog(
                backgroundColor: Colors.transparent,
                child: SizedBox(
                    width: 1150,
                    height: 650,
                    child: GlassSurface(
                        child: Column(children: [
                      Row(children: [
                        const Text('全部应用', style: TextStyle(fontSize: 30)),
                        const Spacer(),
                        IconAction(
                            icon: Icons.close,
                            label: '关闭应用列表',
                            onTap: () => Navigator.pop(context))
                      ]),
                      const SizedBox(height: 22),
                      Expanded(
                          child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 6,
                                      mainAxisSpacing: 24,
                                      crossAxisSpacing: 22),
                              itemCount: apps.length,
                              itemBuilder: (context, i) {
                                final app = mapOf(apps[i]);
                                return TextButton(
                                    onPressed: () => controller.command(
                                        'launch-app',
                                        value: '${app['id']}'),
                                    child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (app['iconBytes'] != null)
                                            Image.memory(app['iconBytes'],
                                                width: 66, height: 66)
                                          else
                                            Icon(Icons.apps,
                                                size: 58,
                                                color: SurfaceStyle.of(context)
                                                    .accent),
                                          const SizedBox(height: 14),
                                          Text('${app['label']}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  const TextStyle(fontSize: 18))
                                        ]));
                              }))
                    ]))));
          });
}

class MediaPanel extends StatelessWidget {
  final LauncherController controller;
  const MediaPanel({super.key, required this.controller});
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: controller.native,
          builder: (context, state, _) {
            final m = mapOf(state['media']),
                available = state['demo'] == true || m['available'] == true;
            return Dialog(
                backgroundColor: Colors.transparent,
                child: SizedBox(
                    width: 800,
                    height: 440,
                    child: GlassSurface(
                        child: Column(children: [
                      Row(children: [
                        const Text('正在播放', style: TextStyle(fontSize: 30)),
                        const Spacer(),
                        IconAction(
                            icon: Icons.close,
                            label: '关闭音乐详情',
                            onTap: () => Navigator.pop(context))
                      ]),
                      const Spacer(),
                      Text('${m['title'] ?? '暂无播放'}',
                          style: const TextStyle(fontSize: 32),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 14),
                      Text('${m['artist'] ?? '等待媒体会话'}'),
                      const SizedBox(height: 22),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final command in [
                              'previous',
                              'toggle-play',
                              'next'
                            ])
                              IconAction(
                                  icon: command == 'previous'
                                      ? Icons.skip_previous_outlined
                                      : command == 'next'
                                          ? Icons.skip_next_outlined
                                          : m['playing'] == true
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                  label: command,
                                  active: command == 'toggle-play',
                                  onTap: available
                                      ? () => controller.command(command)
                                      : null)
                          ]),
                      const Spacer(),
                      TextButton(
                          onPressed: () => controller.command('open-official',
                              value: 'music'),
                          child: const Text('打开原车媒体'))
                    ]))));
          });
}
