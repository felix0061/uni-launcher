part of 'card_content.dart';

String _calendarDetail(Map<String, dynamic> calendar) {
  if (calendar['authorized'] != true) return '轻触授权读取系统日历';
  if (calendar['eventAvailable'] != true) return '系统日历';
  final location = '${calendar['location'] ?? ''}'.trim();
  final begin = (calendar['beginMs'] as num?)?.toInt();
  if (begin == null) return location.isEmpty ? '系统日历' : location;
  final time = DateTime.fromMillisecondsSinceEpoch(begin);
  final clock = calendar['allDay'] == true
      ? '全天'
      : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  return location.isEmpty ? clock : '$clock · $location';
}

class _OemCard extends StatelessWidget {
  final LauncherCard card;
  final LauncherController controller;
  final bool demo;
  const _OemCard(
      {required this.card, required this.controller, required this.demo});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context), editing = controller.editing;
    final account =
        mapOf(mapOf(controller.native.value['systemStatus'])['account']);
    final calendar = mapOf(controller.native.value['calendar']);
    return LayoutBuilder(builder: (context, box) {
      final compact = box.maxHeight < Design.px(380);
      final title =
          card.type == 'member' && card.title == '领克账号' ? '账号' : card.title;
      return _CardCanvas(
          minHeight: card.type == 'member'
              ? 340
              : card.type == 'tpms'
                  ? 310
                  : 300,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Heading(
                title,
                card.type == 'member' ? '账号中心' : specFor(card.type).source,
                cardSymbol(card.type)),
            if (card.type == 'member') ...[
              Expanded(
                  child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: Design.px(compact ? 72 : 140),
                    height: Design.px(compact ? 72 : 140),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: s.soft,
                        border: Border.all(color: s.edge)),
                    child: Center(
                        child: UniIcon('user',
                            size: Design.px(compact ? 38 : 70),
                            color: s.accent))),
                SizedBox(height: Design.px(compact ? 16 : 28)),
                Text(
                    account['known'] == true && account['loggedIn'] == true
                        ? '${account['name'] ?? '领克账号'}'
                        : '领克账号',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: Design.px(compact ? 26 : 34), height: 1.2)),
                SizedBox(height: Design.px(compact ? 10 : 14)),
                Text(
                    demo
                        ? '演示数据'
                        : account['known'] == true
                            ? (account['loggedIn'] == true ? '已登录' : '未登录')
                            : '账号状态未同步',
                    style: TextStyle(
                        fontSize: Design.px(compact ? 18 : 22),
                        color: s.muted)),
              ]))),
              _OpenCardButton('打开账号中心',
                  arrowFirst: true,
                  compact: editing,
                  onTap: () =>
                      controller.command('official-widget', value: 'member')),
            ] else if (card.type == 'cleanup') ...[
              Expanded(
                  child: Row(children: [
                Container(
                    width: Design.px(editing ? 70 : 92),
                    height: Design.px(editing ? 70 : 92),
                    decoration: BoxDecoration(
                        color: s.soft,
                        borderRadius: BorderRadius.circular(s.radius * .8)),
                    child: Center(
                        child: UniIcon('broom',
                            size: Design.px(editing ? 40 : 49),
                            color: s.accent))),
                SizedBox(width: Design.px(26)),
                Expanded(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('—',
                          style: TextStyle(
                              fontSize: Design.px(editing ? 46 : 68),
                              height: 1,
                              fontWeight: FontWeight.w300)),
                      SizedBox(height: Design.px(14)),
                      Text('清理状态未同步',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: Design.px(editing ? 18 : 20),
                              color: s.muted)),
                    ])),
              ])),
              _OpenCardButton('打开清理',
                  compact: editing,
                  onTap: () =>
                      controller.command('official-widget', value: 'cleanup')),
            ] else if (card.type == 'calendar') ...[
              SizedBox(height: Design.px(editing ? 12 : 18)),
              Row(children: [
                Text('${demo ? 24 : calendar['day'] ?? '—'}',
                    style: TextStyle(
                        fontSize: Design.px(editing ? 65 : 94),
                        height: 1,
                        fontWeight: FontWeight.w300,
                        color: s.accent)),
                SizedBox(width: Design.px(26)),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(demo ? '星期六' : '${calendar['weekday'] ?? '日期未同步'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: Design.px(25), height: 1.2)),
                      SizedBox(height: Design.px(12)),
                      Text(
                          demo
                              ? '2026 年 10 月'
                              : '${calendar['monthLabel'] ?? '等待日期'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: Design.px(20),
                              height: 1.2,
                              color: s.muted)),
                    ])),
              ]),
              const Spacer(),
              InkWell(
                  key: const ValueKey('calendar-agenda'),
                  onTap: !demo && calendar['authorized'] != true
                      ? () => controller.command('calendar-access')
                      : null,
                  child: Container(
                      padding:
                          EdgeInsets.only(top: Design.px(editing ? 12 : 20)),
                      decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: s.edge))),
                      child: Row(children: [
                        Container(
                            width: Design.px(4),
                            height: Design.px(39),
                            decoration: BoxDecoration(
                                color: s.accent,
                                borderRadius:
                                    BorderRadius.circular(Design.px(3)))),
                        SizedBox(width: Design.px(16)),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  demo
                                      ? '10:30  车辆保养预约'
                                      : calendar['eventAvailable'] == true
                                          ? '${calendar['title'] ?? '未命名日程'}'
                                          : '${calendar['reason'] ?? '日程未同步'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: Design.px(editing ? 19 : 22),
                                      height: 1.2)),
                              SizedBox(height: Design.px(editing ? 6 : 10)),
                              Text(demo ? '领克中心' : _calendarDetail(calendar),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: Design.px(editing ? 16 : 18),
                                      height: 1.2,
                                      color: s.muted)),
                            ])),
                      ]))),
            ] else if (card.type == 'tpms') ...[
              Expanded(child: TireDiagram(native: controller.native.value)),
              _StateLine(
                  VehicleField.fromNative(
                              controller.native.value, 'pressureFrontLeft')
                          .valid
                      ? '实时胎压 · bar'
                      : '等待车辆数据',
                  dot: true),
            ] else ...[
              Expanded(
                  child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  UniIcon('ride', size: Design.px(60), color: s.accent),
                  SizedBox(width: Design.px(18)),
                  Text('出行服务', style: TextStyle(fontSize: Design.px(30))),
                ]),
                SizedBox(height: Design.px(18)),
                Text('服务信息未同步',
                    style: TextStyle(fontSize: Design.px(20), color: s.muted)),
              ]))),
              const _StateLine('其他车型配置 · 本车未确认'),
            ],
          ]));
    });
  }
}

class _StateLine extends StatelessWidget {
  final String text;
  final bool dot;
  const _StateLine(this.text, {this.dot = false});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return ConstrainedBox(
        constraints: BoxConstraints(minHeight: Design.px(26)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (dot) ...[
            Container(
                width: Design.px(6),
                height: Design.px(6),
                decoration:
                    BoxDecoration(color: s.muted, shape: BoxShape.circle)),
            SizedBox(width: Design.px(10)),
          ],
          Flexible(
              child: Text(text,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: Design.px(18), height: 1.2, color: s.muted))),
        ]));
  }
}

class _TireColors extends ColorMapper {
  final SurfaceStyle s;
  const _TireColors(this.s);
  @override
  Color substitute(
          String? id, String elementName, String attributeName, Color color) =>
      switch (color.toARGB32()) {
        0xffb3d9d9 => s.soft,
        0xffadbdc4 => s.muted,
        0xff71e4ce => s.accent,
        _ => color,
      };
  @override
  bool operator ==(Object other) =>
      other is _TireColors &&
      other.s.soft == s.soft &&
      other.s.muted == s.muted &&
      other.s.accent == s.accent;
  @override
  int get hashCode => Object.hash(s.soft, s.muted, s.accent);
}

class TireDiagram extends StatelessWidget {
  final Map<String, dynamic> native;
  const TireDiagram({super.key, this.native = const {}});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return LayoutBuilder(builder: (context, box) {
      final compact = box.maxHeight < Design.px(300);
      final height = math.min(box.maxHeight, Design.px(440));
      return Center(
          child: SizedBox(
              width: double.infinity,
              height: height,
              child: Stack(children: [
                Center(
                    child: SvgPicture.asset('assets/art/card-tpms.svg',
                        width: Design.px(compact ? 100 : 145),
                        height: math.min(
                            height * .85, Design.px(compact ? 170 : 280)),
                        colorMapper: _TireColors(s))),
                for (final corner in const [
                  ('左前', true, true, 'pressureFrontLeft'),
                  ('右前', false, true, 'pressureFrontRight'),
                  ('左后', true, false, 'pressureRearLeft'),
                  ('右后', false, false, 'pressureRearRight'),
                ])
                  Positioned(
                      left: corner.$2 ? 0 : null,
                      right: corner.$2 ? null : 0,
                      top: corner.$3 ? height * (compact ? .08 : .16) : null,
                      bottom: corner.$3 ? null : height * (compact ? .08 : .12),
                      width: Design.px(90),
                      child: Column(children: [
                        Text(corner.$1,
                            style: TextStyle(
                                fontSize: Design.px(compact ? 17 : 20),
                                height: 1.2,
                                color: s.muted)),
                        SizedBox(height: Design.px(compact ? 5 : 12)),
                        Text(
                            VehicleField.fromNative(native, corner.$4)
                                .display(decimals: 2),
                            style: TextStyle(
                                fontSize: Design.px(compact ? 32 : 46),
                                height: 1.2,
                                fontWeight: FontWeight.w300)),
                        Text('bar',
                            style: TextStyle(
                                fontSize: Design.px(compact ? 14 : 17),
                                height: 1.1,
                                color: s.muted)),
                      ])),
              ])));
    });
  }
}

class _WeatherCard extends StatelessWidget {
  final LauncherCard card;
  final bool demo, editing;
  final Map<String, dynamic> native;
  const _WeatherCard(
      {required this.card,
      required this.demo,
      required this.editing,
      required this.native});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    // The title can also be used as a demo preview city; live weather stays unknown.
    final weather = WeatherSnapshot.fromNative(native);
    final city =
        demo ? (card.title == '天气' ? weather.city : card.title) : weather.city;
    return _CardCanvas(
        minHeight: editing ? 180 : 230,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            UniIcon('pin', size: Design.px(23), color: s.text),
            SizedBox(width: Design.px(8)),
            Expanded(
                child: Text(city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: Design.px(23), height: 1.2))),
            Text(weather.source.replaceAll('原车', ''),
                style: TextStyle(fontSize: Design.px(20), color: s.muted)),
          ]),
          Expanded(
              child: Row(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(weather.temperature?.toString() ?? '—',
                  style: TextStyle(
                      fontSize: Design.px(editing ? 48 : 65),
                      height: 1,
                      fontWeight: FontWeight.w400,
                      letterSpacing: Design.px(-2))),
              Padding(
                  padding: EdgeInsets.only(top: Design.px(7)),
                  child: Text('°',
                      style: TextStyle(
                          fontSize: Design.px(editing ? 28 : 36), height: 1))),
            ]),
            SizedBox(width: Design.px(20)),
            Expanded(
                child: Text(weather.description,
                    style: TextStyle(fontSize: Design.px(25)))),
            WeatherIcon(
                condition: weather.condition,
                night: weather.night,
                size: Design.px(editing ? 80 : 100),
                color: s.accent),
          ])),
          if (!editing)
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('天气',
                  style: TextStyle(fontSize: Design.px(17), color: s.muted)),
              Flexible(
                  child: Text(
                      weather.available
                          ? '已同步'
                          : '${(mapOf(native['weather'])['reason'] ?? '等待天气同步').toString().replaceAll('原车', '')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: Design.px(17), color: s.muted))),
            ]),
        ]));
  }
}

class _ShortcutCard extends StatelessWidget {
  final LauncherCard card;
  final LauncherController controller;
  const _ShortcutCard({required this.card, required this.controller});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return _CardCanvas(
        minHeight: 230,
        child: Column(children: [
          Row(children: [
            Expanded(
                child: Text(card.title,
                    style: TextStyle(
                        fontSize: Design.px(23), height: 1.2, color: s.muted))),
            UniIcon('apps', size: Design.px(32), color: s.muted)
          ]),
          SizedBox(height: Design.px(29)),
          Expanded(
              child: Align(
                  alignment: Alignment.topCenter,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final item in const [
                          ('nav', '导航'),
                          ('phone', '电话'),
                          ('music', '音乐'),
                          ('settings', '系统设置'),
                        ])
                          Flexible(
                              child: Semantics(
                                  button: true,
                                  label: item.$2,
                                  child: GestureDetector(
                                      onTap: () => item.$1 == 'music'
                                          ? showMediaPanel(context, controller)
                                          : controller.command('open-official',
                                              value: item.$1),
                                      child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                    width: Design.px(74),
                                                    height: Design.px(74),
                                                    decoration: BoxDecoration(
                                                        color: s.soft,
                                                        borderRadius: BorderRadius
                                                            .circular(s
                                                                .controlRadius)),
                                                    child: Center(
                                                        child: UniIcon(item.$1,
                                                            size: Design.px(33),
                                                            color: s.text))),
                                                SizedBox(height: Design.px(15)),
                                                Text(item.$2,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                        fontSize: Design.px(20),
                                                        height: 1.2,
                                                        color: s.muted)),
                                              ]))))),
                      ]))),
        ]));
  }
}
