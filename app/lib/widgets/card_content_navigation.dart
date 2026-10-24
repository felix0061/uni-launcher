part of 'card_content.dart';

/// Palette substitution preserves the original SVG geometry across themes.
class _MapColors extends ColorMapper {
  final SurfaceStyle s;
  const _MapColors(this.s);
  @override
  Color substitute(
          String? id, String elementName, String attributeName, Color color) =>
      switch (color.toARGB32()) {
        0xff71e4ce => s.accent,
        0xff16232b => s.surface,
        0xff92bbbe =>
          s.dark ? const Color(0x2b92bbbe) : const Color(0xd6ffffff),
        0xff92bbbf =>
          s.dark ? const Color(0x1c92bbbe) : const Color(0x94ffffff),
        0xff2f7d97 =>
          s.dark ? const Color(0x292f7d97) : const Color(0x3377b4c8),
        0xff76ad84 =>
          s.dark ? const Color(0x1476ad84) : const Color(0x47accca7),
        0xff0b3b39 =>
          s.dark ? const Color(0xff0b3b39) : const Color(0xffdaf5eb),
        _ => color,
      };
  @override
  bool operator ==(Object other) =>
      other is _MapColors &&
      other.s.dark == s.dark &&
      other.s.accent == s.accent &&
      other.s.surface == s.surface;
  @override
  int get hashCode => Object.hash(s.dark, s.accent, s.surface);
}

class _NavigationDemo extends StatefulWidget {
  const _NavigationDemo();
  @override
  State<_NavigationDemo> createState() => _NavigationDemoState();
}

class _NavigationDemoState extends State<_NavigationDemo> {
  double zoom = 1;
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return _CardCanvas(
        padded: false,
        minWidth: 620,
        minHeight: 330,
        child: LayoutBuilder(builder: (context, box) {
          final compact = box.maxHeight < Design.px(500);
          return Stack(children: [
            Positioned.fill(
                child: ColoredBox(
                    color: Colors.transparent,
                    child: ClipRect(
                        child: Transform.scale(
                            scale: zoom,
                            child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                    width: 1144,
                                    height: 732,
                                    child: Stack(children: [
                                      Positioned.fill(
                                          child: SvgPicture.asset(
                                              'assets/art/card-map.svg',
                                              fit: BoxFit.fill,
                                              colorMapper: _MapColors(s))),
                                      // Flutter overlays the original map labels (SVG text is unsupported).
                                      for (final label in const [
                                        ('城市公园', 110.0, 337.0, false),
                                        ('文化广场', 724.0, 530.0, false),
                                        ('城市大道', 710.0, 205.0, false),
                                        ('滨河路', 225.0, 440.0, false),
                                        ('环城东路', 836.0, 350.0, true),
                                      ])
                                        Positioned(
                                            left: label.$2,
                                            top: label.$3 - 24,
                                            child: Transform.rotate(
                                                angle:
                                                    label.$4 ? math.pi / 2 : 0,
                                                alignment: Alignment.topLeft,
                                                child: Text(label.$1,
                                                    style: TextStyle(
                                                        fontSize: 22,
                                                        height: 1,
                                                        letterSpacing: 2,
                                                        color: s.dark
                                                            ? const Color(
                                                                0xff8ca5aa)
                                                            : const Color(
                                                                0xff6b8780))))),
                                      Positioned.fill(
                                          child: SvgPicture.asset(
                                              'assets/art/card-map-route.svg',
                                              fit: BoxFit.fill,
                                              colorMapper: _MapColors(s))),
                                    ]))))))),
            Positioned(
                top: Design.px(28),
                left: Design.px(28),
                child: GlassSurface(
                    tone: SurfaceTone.strong,
                    radius: s.radius * .79,
                    padding: EdgeInsets.fromLTRB(
                        Design.px(26),
                        Design.px(compact ? 16 : 25),
                        Design.px(32),
                        Design.px(compact ? 16 : 25)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: Design.px(compact ? 58 : 78),
                          height: Design.px(compact ? 58 : 78),
                          decoration: BoxDecoration(
                              color: s.accent,
                              borderRadius:
                                  BorderRadius.circular(s.controlRadius)),
                          child: Center(
                              child: UniIcon('turn',
                                  size: Design.px(compact ? 36 : 46),
                                  color: s.accentText))),
                      SizedBox(width: Design.px(22)),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('600 米后右转',
                                style: TextStyle(
                                    fontSize: Design.px(compact ? 28 : 38),
                                    height: 1.2,
                                    fontWeight: FontWeight.w500)),
                            SizedBox(height: Design.px(8)),
                            Text('进入城市大道',
                                style: TextStyle(
                                    fontSize: Design.px(compact ? 18 : 24),
                                    height: 1.2,
                                    color: s.muted)),
                          ]),
                    ]))),
            Positioned(
                top: Design.px(28),
                right: Design.px(28),
                width: Design.px(55),
                child: Column(children: [
                  Text('N',
                      style:
                          TextStyle(fontSize: Design.px(20), color: s.muted)),
                  SizedBox(height: Design.px(7)),
                  Transform.rotate(
                      angle: -.4,
                      child:
                          UniIcon('nav', size: Design.px(22), color: s.text)),
                ])),
            Positioned(
                right: Design.px(24),
                bottom: Design.px(compact ? 136 : 176),
                child: GlassSurface(
                    radius: s.controlRadius,
                    padding: EdgeInsets.zero,
                    shadow: false,
                    child: Column(children: [
                      IconAction(
                          icon: Icons.add,
                          label: '放大示例地图',
                          size: Design.px(64),
                          iconSize: Design.px(32),
                          onTap: zoom < 1.8
                              ? () => setState(
                                  () => zoom = math.min(1.8, zoom + .2))
                              : null),
                      SizedBox(
                          width: Design.px(64),
                          child: Divider(height: 1, color: s.edge)),
                      IconAction(
                          icon: Icons.remove,
                          label: '缩小示例地图',
                          size: Design.px(64),
                          iconSize: Design.px(32),
                          onTap: zoom > 1
                              ? () =>
                                  setState(() => zoom = math.max(1, zoom - .2))
                              : null),
                    ]))),
            Positioned(
                bottom: Design.px(28),
                left: Design.px(28),
                right: Design.px(28),
                child: GlassSurface(
                    tone: SurfaceTone.strong,
                    radius: s.radius * .79,
                    padding: EdgeInsets.symmetric(
                        horizontal: Design.px(29),
                        vertical: Design.px(compact ? 16 : 23)),
                    child: Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('前往 · 城市中心',
                                style: TextStyle(
                                    fontSize: Design.px(20), color: s.muted)),
                            SizedBox(height: Design.px(8)),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text('10:08 到达',
                                      style: TextStyle(
                                          fontSize:
                                              Design.px(compact ? 28 : 36),
                                          height: 1.2,
                                          fontWeight: FontWeight.w500)),
                                  SizedBox(width: Design.px(20)),
                                  Flexible(
                                      child: Text('27 分钟 · 12.6 公里',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: Design.px(22),
                                              color: s.muted))),
                                ]),
                          ])),
                      Container(
                          width: Design.px(56),
                          height: Design.px(56),
                          decoration: BoxDecoration(
                              color: s.soft,
                              borderRadius:
                                  BorderRadius.circular(s.controlRadius)),
                          child: Center(
                              child: UniIcon('nav',
                                  size: Design.px(28), color: s.accent))),
                    ]))),
          ]);
        }));
  }
}

class _NavigationWaiting extends StatelessWidget {
  final LauncherCard card;
  final LauncherController controller;
  const _NavigationWaiting({required this.card, required this.controller});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return _CardCanvas(
        minHeight: 280,
        child: Column(children: [
          _Heading(card.title, '原车导航服务', 'nav'),
          Expanded(
              child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
            UniIcon('nav', size: Design.px(60), color: s.accent),
            SizedBox(height: Design.px(18)),
            Text('等待原车导航信息', style: TextStyle(fontSize: Design.px(28))),
          ]))),
          _OpenCardButton('打开原车导航',
              onTap: () => controller.command('open-official', value: 'nav')),
        ]));
  }
}
