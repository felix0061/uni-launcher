import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controller/launcher_controller.dart';
import '../model/appearance.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';
import '../widgets/glass_surface.dart';
import '../widgets/card_content.dart';
import '../widgets/desktop.dart';
import '../widgets/bottom_dock.dart';
import '../widgets/scene_background.dart';
import '../widgets/uni_icon.dart';
import '../widgets/launcher_dialog.dart';
import '../widgets/embedded_navigation.dart';
import '../widgets/integration_settings.dart';

class SettingsScreen extends StatelessWidget {
  final LauncherController controller;
  const SettingsScreen({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final c = controller, s = SurfaceStyle.of(context);
    return SettingsControllerScope(
        controller: c,
        child: Padding(
            padding: EdgeInsets.fromLTRB(
                Design.px(32), Design.px(16), Design.px(32), Design.px(24)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                      height: Design.px(78),
                      child: Row(children: [
                        IconAction(
                            icon: Icons.arrow_back,
                            label: '返回桌面',
                            onTap: c.home,
                            soft: true,
                            size: Design.px(64)),
                        SizedBox(width: Design.px(24)),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('桌面设置',
                                  style: TextStyle(
                                      fontSize: Design.px(36),
                                      fontWeight: FontWeight.w500)),
                              SizedBox(height: Design.px(9)),
                              Text('外观、配色与卡片布局',
                                  style: TextStyle(
                                      fontSize: Design.px(20), color: s.muted))
                            ]),
                        const Spacer(),
                        UniIcon('check', size: Design.px(23), color: s.accent),
                        SizedBox(width: Design.px(10)),
                        Text(c.message.isEmpty ? '更改自动保存' : c.message,
                            style: TextStyle(
                                color: s.muted, fontSize: Design.px(19)))
                      ])),
                  SizedBox(height: Design.px(24)),
                  Container(
                      height: Design.px(60),
                      decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: s.edge))),
                      child: Row(children: [
                        for (final tab in [
                          ('appearance', '外观主题'),
                          ('layout', '卡片布局'),
                          ('motion', '切换动效'),
                          ('sources', '功能接入')
                        ])
                          _SettingsTab(controller: c, id: tab.$1, label: tab.$2)
                      ])),
                  SizedBox(height: Design.px(24)),
                  Expanded(
                      child: switch (c.settingsTab) {
                    'appearance' => LayoutBuilder(
                        builder: (context, box) => SingleChildScrollView(
                            child: SizedBox(
                                height: box.maxHeight < Design.px(620)
                                    ? Design.px(620)
                                    : box.maxHeight,
                                child: AppearanceSettings(controller: c)))),
                    'layout' => GlassSurface(
                          child: Row(children: [
                        Expanded(
                            child: Padding(
                                padding: EdgeInsets.all(Design.px(50)),
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('DESKTOP / LAYOUT',
                                          style: TextStyle(
                                              color: s.accent,
                                              letterSpacing: 2)),
                                      SizedBox(height: Design.px(26)),
                                      Text('桌面，由你编排。',
                                          style: TextStyle(
                                              fontSize: Design.px(44))),
                                      SizedBox(height: Design.px(26)),
                                      Text('长按卡片进入编辑，移动、缩放、添加或移除。',
                                          style: TextStyle(
                                              fontSize: Design.px(24),
                                              height: 1.8,
                                              color: s.muted)),
                                      SizedBox(height: Design.px(36)),
                                      Wrap(spacing: Design.px(18), children: [
                                        FilledButton.icon(
                                            key: const ValueKey('start-edit'),
                                            onPressed: c.beginEdit,
                                            icon: const UniIcon('edit'),
                                            label: const Text('编辑桌面布局')),
                                        TextButton(
                                            onPressed: c.resetLayout,
                                            child: const Text('恢复默认布局'))
                                      ])
                                    ]))),
                        Expanded(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                              for (final hint in [
                                ('move', '移动卡片', '拖动标题，在网格中吸附'),
                                ('resize', '调整大小', '拖动右下角，选择合适尺寸'),
                                ('apps', '添加与移除', '从原车卡片和桌面扩展中选择')
                              ])
                                Padding(
                                    padding: EdgeInsets.symmetric(
                                        vertical: Design.px(17)),
                                    child: Row(children: [
                                      UniIcon(hint.$1,
                                          size: Design.px(44), color: s.accent),
                                      SizedBox(width: Design.px(26)),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(hint.$2,
                                                style: TextStyle(
                                                    fontSize: Design.px(27))),
                                            SizedBox(height: Design.px(10)),
                                            Text(hint.$3,
                                                style: TextStyle(
                                                    fontSize: Design.px(21),
                                                    color: s.muted))
                                          ]))
                                    ]))
                            ]))
                      ])),
                    'motion' => PageMotionSettings(controller: c),
                    _ => SourceSettings(controller: c)
                  }),
                ])));
  }
}

class _SettingsTab extends StatelessWidget {
  final LauncherController controller;
  final String id, label;
  const _SettingsTab(
      {required this.controller, required this.id, required this.label});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context), selected = controller.settingsTab == id;
    return Padding(
        padding: EdgeInsets.only(right: Design.px(12)),
        child: InkWell(
            key: ValueKey('tab-$id'),
            onTap: () => controller.tab(id),
            child: Padding(
                padding: EdgeInsets.symmetric(horizontal: Design.px(30)),
                child: Container(
                    key: ValueKey('tab-indicator-$id'),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                width: Design.px(3),
                                color:
                                    selected ? s.accent : Colors.transparent))),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: Design.px(24),
                            color: selected ? s.accent : s.muted))))));
  }
}

class SettingBlock extends StatelessWidget {
  final String title;
  final String? note;
  final Widget child;
  final bool compact;
  const SettingBlock(
      {super.key,
      required this.title,
      this.note,
      required this.child,
      this.compact = false});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return GlassSurface(
        padding: EdgeInsets.symmetric(
            horizontal: Design.px(30), vertical: Design.px(compact ? 16 : 22)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text(title,
                style: TextStyle(
                    fontSize: Design.px(26), fontWeight: FontWeight.w500)),
            if (note != null) ...[
              const Spacer(),
              Text(note!,
                  style: TextStyle(color: s.muted, fontSize: Design.px(18)))
            ]
          ]),
          SizedBox(height: Design.px(18)),
          child
        ]));
  }
}

class AppearanceSettings extends StatelessWidget {
  final LauncherController controller;
  const AppearanceSettings({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final c = controller, a = c.appearance, s = SurfaceStyle.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
          child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                      child: Column(children: [
                    SettingBlock(
                        compact: box.maxHeight < Design.px(650),
                        title: '显示模式',
                        note: '选择适合此刻的明暗',
                        child: Row(children: [
                          for (final mode in [
                            ('system', 'auto-theme', '跟随系统'),
                            ('light', 'sun', '浅色'),
                            ('dark', 'moon', '深色')
                          ])
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.only(
                                        right: mode.$1 == 'dark'
                                            ? 0
                                            : Design.px(14)),
                                    child: SizedBox(
                                        height: Design.px(66),
                                        child: OutlinedButton(
                                            key: ValueKey('mode-${mode.$1}'),
                                            onPressed: () => c.setAppearance(
                                                a.copyWith(mode: mode.$1)),
                                            style: OutlinedButton.styleFrom(
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            s.controlRadius)),
                                                foregroundColor:
                                                    a.mode == mode.$1
                                                        ? s.accent
                                                        : s.text,
                                                side: BorderSide(
                                                    color: a.mode == mode.$1
                                                        ? s.accent
                                                        : s.edge)),
                                            child:
                                                Stack(alignment: Alignment.center, children: [
                                              Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    UniIcon(mode.$2,
                                                        size: Design.px(26)),
                                                    SizedBox(
                                                        width: Design.px(14)),
                                                    Text(mode.$3,
                                                        style: TextStyle(
                                                            fontSize:
                                                                Design.px(22)))
                                                  ]),
                                              if (a.mode == mode.$1)
                                                Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: UniIcon('check',
                                                        size: Design.px(20)))
                                            ])))))
                        ])),
                    SizedBox(height: Design.px(16)),
                    SettingBlock(
                        compact: box.maxHeight < Design.px(650),
                        title: '主题配色',
                        note: '同步改变强调色与背景氛围',
                        child: Column(children: [
                          Row(children: [
                            for (final preset in accentPresets)
                              Expanded(
                                  child: Padding(
                                      padding: EdgeInsets.only(
                                          right:
                                              preset.id == accentPresets.last.id
                                                  ? 0
                                                  : Design.px(14)),
                                      child: SizedBox(
                                          height: Design.px(138),
                                          child: OutlinedButton(
                                              key: ValueKey(
                                                  'palette-${preset.id}'),
                                              onPressed: () => c.setAppearance(
                                                  a.copyWith(
                                                      palette: preset.id)),
                                              style: OutlinedButton.styleFrom(
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: Design.px(17),
                                                      horizontal:
                                                          Design.px(10)),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              s.controlRadius)),
                                                  foregroundColor: s.text,
                                                  side: BorderSide(color: a.palette == preset.id ? s.accent : s.edge)),
                                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                                Container(
                                                    width: Design.px(59),
                                                    height: Design.px(59),
                                                    decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: preset.seed),
                                                    child: a.palette ==
                                                            preset.id
                                                        ? const Center(
                                                            child: UniIcon(
                                                                'check',
                                                                size: 22,
                                                                color: Colors
                                                                    .white))
                                                        : null),
                                                SizedBox(height: Design.px(14)),
                                                Text(preset.name,
                                                    style: TextStyle(
                                                        fontSize:
                                                            Design.px(21)))
                                              ])))))
                          ]),
                          SizedBox(height: Design.px(28)),
                          Divider(height: 1, color: s.edge),
                          SizedBox(height: Design.px(22)),
                          CustomColorRow(controller: c),
                        ])),
                    SizedBox(height: Design.px(16)),
                    RadiusSetting(controller: c),
                  ])))),
      SizedBox(width: Design.px(24)),
      SizedBox(
          width: Design.px(620),
          child: GlassSurface(
              padding: EdgeInsets.all(Design.px(30)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Text('实时预览',
                          style: TextStyle(
                              fontSize: Design.px(26),
                              fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text(
                          '${s.dark ? '深色' : '浅色'} · ${a.palette == 'custom' ? '自定义' : accentPresets.firstWhere((p) => p.id == a.palette).name}',
                          style: TextStyle(
                              fontSize: Design.px(18), color: s.muted))
                    ]),
                    SizedBox(height: Design.px(22)),
                    const Flexible(child: DesktopPreview()),
                    SizedBox(height: Design.px(22)),
                    Row(children: [
                      Container(
                          width: Design.px(52),
                          height: Design.px(52),
                          decoration: BoxDecoration(
                              color: s.accent,
                              borderRadius:
                                  BorderRadius.circular(s.radius * .61))),
                      SizedBox(width: Design.px(20)),
                      Expanded(
                          child: Text('路线、播放按钮与选中状态\n使用同一组主题色',
                              style: TextStyle(
                                  fontSize: Design.px(18),
                                  height: 1.5,
                                  color: s.muted)))
                    ]),
                    SizedBox(height: Design.px(16)),
                    Container(
                        padding: EdgeInsets.only(top: Design.px(16)),
                        decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: s.edge))),
                        child: Row(children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('毛玻璃',
                                    style: TextStyle(fontSize: Design.px(23))),
                                SizedBox(height: Design.px(6)),
                                Text('关闭后保留半透明材质',
                                    style: TextStyle(
                                        fontSize: Design.px(17),
                                        color: s.muted))
                              ])),
                          DesignToggle(
                              key: const ValueKey('glass-switch'),
                              label: '毛玻璃',
                              value: a.glass,
                              onChanged: (v) =>
                                  c.setAppearance(a.copyWith(glass: v)))
                        ])),
                    SizedBox(height: Design.px(18)),
                    OutlinedButton.icon(
                        onPressed: c.home,
                        icon: const UniIcon('home'),
                        label: const Text('返回桌面查看'))
                  ]))),
    ]);
  }
}

/// The preview reuses the actual desktop renderer rather than a separate icon sketch.
class DesktopPreview extends StatelessWidget {
  const DesktopPreview({super.key});
  @override
  Widget build(BuildContext context) {
    final c = SettingsControllerScope.of(context), s = SurfaceStyle.of(context);
    return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
            borderRadius: BorderRadius.circular(s.radius * .64),
            child: IgnorePointer(
                child: EmbeddedContentPolicy(
                    enabled: false,
                    child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                            width: Design.canvasWidth,
                            height: 900,
                            child: SceneBackground(
                                child: Column(children: [
                              Header(controller: c),
                              Expanded(child: Desktop(controller: c)),
                              Padding(
                                  padding: EdgeInsets.fromLTRB(Design.px(32), 0,
                                      Design.px(32), Design.px(16)),
                                  child: BottomDock(controller: c))
                            ]))))))));
  }
}

class SettingsControllerScope extends InheritedWidget {
  final LauncherController controller;
  const SettingsControllerScope(
      {super.key, required this.controller, required super.child});
  static LauncherController of(BuildContext c) => c
      .dependOnInheritedWidgetOfExactType<SettingsControllerScope>()!
      .controller;
  @override
  bool updateShouldNotify(SettingsControllerScope old) =>
      old.controller != controller;
}

class RadiusSetting extends StatelessWidget {
  final LauncherController controller;
  const RadiusSetting({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final c = controller, a = c.appearance, s = SurfaceStyle.of(context);
    return GlassSurface(
        padding: EdgeInsets.symmetric(
            horizontal: Design.px(30), vertical: Design.px(22)),
        child: Row(children: [
          SizedBox(
              width: Design.px(228),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('卡片圆角', style: TextStyle(fontSize: Design.px(23))),
                    SizedBox(height: Design.px(10)),
                    Text('0 为直角 · 默认 28px',
                        style:
                            TextStyle(fontSize: Design.px(17), color: s.muted))
                  ])),
          Text('0', style: TextStyle(color: s.muted)),
          Expanded(
              child: Slider(
                  key: const ValueKey('radius-slider'),
                  value: a.radius,
                  min: 0,
                  max: 40,
                  divisions: 40,
                  onChanged: (v) =>
                      c.setAppearance(a.copyWith(radius: v), save: false),
                  onChangeEnd: (_) => c.persist())),
          Text('40', style: TextStyle(color: s.muted)),
          SizedBox(width: Design.px(18)),
          SizedBox(
              width: Design.px(122),
              child: TextFormField(
                  key: ValueKey('radius-number-${a.radius.round()}'),
                  initialValue: '${a.radius.round()}',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3)
                  ],
                  style: TextStyle(fontSize: Design.px(24)),
                  decoration: const InputDecoration(suffixText: 'px'),
                  onFieldSubmitted: (v) => c.setAppearance(a.copyWith(
                      radius: (double.tryParse(v) ?? a.radius).clamp(0, 40)))))
        ]));
  }
}

class CustomColorRow extends StatefulWidget {
  final LauncherController controller;
  const CustomColorRow({super.key, required this.controller});
  @override
  State<CustomColorRow> createState() => _CustomColorRowState();
}

class _CustomColorRowState extends State<CustomColorRow> {
  late final TextEditingController input;
  String? error;
  @override
  void initState() {
    super.initState();
    input = TextEditingController(text: widget.controller.appearance.custom);
  }

  @override
  void didUpdateWidget(CustomColorRow old) {
    super.didUpdateWidget(old);
    if (old.controller.appearance.custom != input.text &&
        !input.selection.isValid)
      input.text = widget.controller.appearance.custom;
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void apply() {
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(input.text)) {
      setState(() => error = '使用 #RRGGBB');
      return;
    }
    setState(() => error = null);
    widget.controller.setAppearance(widget.controller.appearance
        .copyWith(palette: 'custom', custom: input.text.toUpperCase()));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, s = SurfaceStyle.of(context);
    return Row(children: [
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('自定义颜色', style: TextStyle(fontSize: Design.px(22))),
        SizedBox(height: Design.px(10)),
        Text('从取色器选择，或输入 HEX 色值',
            style: TextStyle(fontSize: Design.px(17), color: s.muted))
      ])),
      InkWell(
          key: const ValueKey('custom-color'),
          onTap: () async {
            final value = await editCustomColor(context, c);
            if (value != null) input.text = value;
          },
          child: GlassSurface(
              tone: SurfaceTone.soft,
              radius: s.radius * .61,
              padding: EdgeInsets.all(Design.px(8)),
              shadow: false,
              child: Container(
                  width: Design.px(34),
                  height: Design.px(34),
                  decoration: BoxDecoration(
                      color: Color(0xFF000000 |
                          int.parse(c.appearance.custom.substring(1),
                              radix: 16)),
                      borderRadius: BorderRadius.circular(s.radius * .29))))),
      SizedBox(width: Design.px(12)),
      SizedBox(
          width: Design.px(138),
          child: TextField(
              key: const ValueKey('hex-field'),
              controller: input,
              maxLength: 7,
              style:
                  TextStyle(fontSize: Design.px(20), fontFamily: 'monospace'),
              decoration: InputDecoration(
                  counterText: '', errorText: error, isDense: true),
              onSubmitted: (_) => apply())),
      TextButton(onPressed: apply, child: const Text('应用'))
    ]);
  }
}

Future<String?> editCustomColor(BuildContext context, LauncherController c) {
  HSVColor hsv = HSVColor.fromColor(Color(
      0xFF000000 | int.parse(c.appearance.custom.substring(1), radix: 16)));
  return showLauncherSheet<String>(context,
      title: '自定义主题色',
      subtitle: '选择色相、饱和度与明度',
      closeLabel: '关闭取色器',
      width: Design.px(720),
      builder: (context) => StatefulBuilder(builder: (context, setState) {
            final color = hsv.toColor(),
                hex =
                    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
            return SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(height: Design.px(100), color: color),
              SizedBox(height: Design.px(20)),
              Text(hex, style: TextStyle(fontSize: Design.px(26))),
              for (final item in [
                ('色相', hsv.hue, 360.0),
                ('饱和度', hsv.saturation, 1.0),
                ('明度', hsv.value, 1.0)
              ])
                Row(children: [
                  SizedBox(width: Design.px(80), child: Text(item.$1)),
                  Expanded(
                      child: Slider(
                          value: item.$2,
                          max: item.$3,
                          onChanged: (v) => setState(() => hsv = item.$1 == '色相'
                              ? hsv.withHue(v)
                              : item.$1 == '饱和度'
                                  ? hsv.withSaturation(v)
                                  : hsv.withValue(v))))
                ]),
              FilledButton(
                  onPressed: () {
                    c.setAppearance(
                        c.appearance.copyWith(palette: 'custom', custom: hex));
                    Navigator.pop(context, hex);
                  },
                  child: const Text('应用颜色'))
            ]));
          }));
}

class SourceSettings extends StatelessWidget {
  final LauncherController controller;
  const SourceSettings({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<
          Map<String, dynamic>>(
      valueListenable: controller.native,
      builder: (context, n, _) {
        final c = controller, s = SurfaceStyle.of(context);
        final sources = [
          ('nav', 'nav', '导航', '原车导航服务'),
          ('music', 'music', '音乐', '原车媒体中心'),
          ('weather', 'cloud', '天气', '原车天气'),
          ('calendar', 'calendar', '日历', '原车日历'),
          ('member', 'user', '领克账号', '原车账号中心'),
          ('cleanup', 'broom', '系统清理', '原车安全中心'),
          ('tpms', 'tire', '车辆与胎压', '原车车辆信息'),
          ('air', 'air', '空气质量', '按车型支持')
        ];
        return ListView(children: [
          IntegrationSettings(controller: c, native: n),
          SizedBox(height: Design.px(16)),
          GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sources.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: Design.px(132),
                  crossAxisSpacing: Design.px(16),
                  mainAxisSpacing: Design.px(16)),
              itemBuilder: (context, index) {
                final item = sources[index];
                return GlassSurface(
                    padding: EdgeInsets.symmetric(
                        horizontal: Design.px(24), vertical: Design.px(22)),
                    child: Row(children: [
                      UniIcon(item.$2, size: Design.px(40), color: s.accent),
                      SizedBox(width: Design.px(16)),
                      Expanded(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(item.$3,
                                style: TextStyle(fontSize: Design.px(25))),
                            SizedBox(height: Design.px(14)),
                            Text(item.$4,
                                style: TextStyle(
                                    color: s.muted, fontSize: Design.px(16)))
                          ])),
                      Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: Design.px(12),
                              vertical: Design.px(8)),
                          decoration: BoxDecoration(
                              color: s.soft,
                              borderRadius:
                                  BorderRadius.circular(s.controlRadius)),
                          child: Text(
                              item.$1 == 'music' &&
                                      mapOf(n['media'])['authorized'] == true
                                  ? '媒体已授权'
                                  : '待接入',
                              style: TextStyle(
                                  color: s.muted, fontSize: Design.px(15))))
                    ]));
              }),
          SizedBox(height: Design.px(16)),
          GlassSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Row(children: [
                  Expanded(
                      child: Text(
                          '${mapOf(n['vehicle'])['reason'] ?? '未连接原车服务'}',
                          style: TextStyle(
                              fontSize: Design.px(20), color: s.muted))),
                  TextButton(
                      onPressed: () => c.command('refresh'),
                      child: const Text('刷新连接')),
                  TextButton(
                      onPressed: () => c.command('media-access'),
                      child: const Text('授权媒体访问'))
                ]),
                SwitchListTile(
                    key: const ValueKey('demo-switch'),
                    title: const Text('演示数据'),
                    subtitle: const Text('关闭后显示真实接入状态'),
                    value: n['demo'] == true,
                    onChanged: (v) => c.command('demo-mode', enabled: v)),
                SwitchListTile(
                    key: const ValueKey('global-dock'),
                    title: const Text('全局底栏'),
                    subtitle: Text(mapOf(n['globalDock'])['allowed'] == true
                        ? '在其他应用中使用相同的首页、空调和音乐控制'
                        : '开启后需允许悬浮显示'),
                    value: mapOf(n['globalDock'])['enabled'] == true,
                    onChanged: (v) => c.command('global-dock', enabled: v)),
                SwitchListTile(
                    key: const ValueKey('system-navigation-hidden'),
                    title: const Text('隐藏系统原有导航栏'),
                    subtitle: Text(n['systemNavigationGranted'] == true
                        ? '关闭后恢复原有显示；与全局底栏分别设置'
                        : '需要系统授予导航栏管理权限'),
                    value: n['systemNavigationHidden'] == true,
                    onChanged: n['systemNavigationGranted'] == true
                        ? (v) =>
                            c.command('system-navigation-hidden', enabled: v)
                        : null),
                Row(children: [
                  Text('UNI 0.5.0 · xyz.i4o.uni.launcher',
                      style:
                          TextStyle(fontSize: Design.px(18), color: s.muted)),
                  const Spacer(),
                  TextButton(
                      onPressed: () =>
                          c.command('open-official', value: 'settings'),
                      child: const Text('打开原车设置'))
                ])
              ]))
        ]);
      });
}

class PageMotionSettings extends StatelessWidget {
  final LauncherController controller;
  const PageMotionSettings({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context), c = controller;
    return SingleChildScrollView(
        child: SettingBlock(
            title: '桌面翻屏',
            note: '仅桌面卡片切换，底栏保持固定',
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    for (final option in [
                      ('none', '无动画', '直接切换，画面不滑动'),
                      ('fade', '淡入淡出', '柔和交替显示'),
                      ('slide', '横向滑动', '跟随翻页方向滑入')
                    ])
                      Expanded(
                          child: Padding(
                              padding: EdgeInsets.only(
                                  right:
                                      option.$1 == 'slide' ? 0 : Design.px(18)),
                              child: OutlinedButton(
                                  key: ValueKey('transition-${option.$1}'),
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          c.appearance.pageTransition == option.$1
                                              ? s.accent
                                              : s.text,
                                      backgroundColor:
                                          c.appearance.pageTransition == option.$1
                                              ? s.soft
                                              : null,
                                      side: BorderSide(
                                          color: c.appearance.pageTransition ==
                                                  option.$1
                                              ? s.accent
                                              : s.edge)),
                                  onPressed: () => c.setAppearance(c.appearance
                                      .copyWith(pageTransition: option.$1)),
                                  child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: Design.px(36)),
                                      child: Column(children: [
                                        Text(option.$2,
                                            style: TextStyle(
                                                fontSize: Design.px(28))),
                                        SizedBox(height: Design.px(16)),
                                        Text(option.$3,
                                            style: TextStyle(
                                                fontSize: Design.px(20),
                                                color: s.muted)),
                                        SizedBox(height: Design.px(22)),
                                        UniIcon('check',
                                            size: Design.px(26),
                                            color:
                                                c.appearance.pageTransition ==
                                                        option.$1
                                                    ? s.accent
                                                    : Colors.transparent)
                                      ]))))),
                  ]),
                  SizedBox(height: Design.px(26)),
                  Text('点击页码或左右轻扫切换桌面。编辑布局时暂停动效；系统要求减少动态效果时使用无动画。',
                      style: TextStyle(
                          fontSize: Design.px(21), color: s.muted, height: 1.6))
                ])));
  }
}
