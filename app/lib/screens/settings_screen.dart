import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../model/appearance.dart';
import '../theme/launcher_theme.dart';
import '../widgets/card_content.dart';
import '../widgets/glass_surface.dart';

class SettingsScreen extends StatelessWidget {
  final LauncherController controller;
  const SettingsScreen({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final c = controller, s = SurfaceStyle.of(context);
    return Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
        child: Column(children: [
          SizedBox(
              height: 88,
              child: Row(children: [
                IconAction(
                    icon: Icons.arrow_back, label: '返回桌面', onTap: c.home),
                const SizedBox(width: 20),
                const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('桌面设置', style: TextStyle(fontSize: 30)),
                      SizedBox(height: 8),
                      Text('外观、配色与卡片布局', style: TextStyle(fontSize: 16))
                    ]),
                const Spacer(),
                Text(c.message.isEmpty ? '更改自动保存' : c.message,
                    style: TextStyle(color: s.muted, fontSize: 16))
              ])),
          SizedBox(
              height: 54,
              child: Row(children: [
                for (final tab in [
                  ('appearance', '外观主题'),
                  ('layout', '卡片布局'),
                  ('sources', '功能接入')
                ])
                  Padding(
                      padding: const EdgeInsets.only(right: 18),
                      child: TextButton(
                          key: ValueKey('tab-${tab.$1}'),
                          onPressed: () => c.tab(tab.$1),
                          style: TextButton.styleFrom(
                              foregroundColor:
                                  c.settingsTab == tab.$1 ? s.accent : s.muted),
                          child: Text(tab.$2,
                              style: const TextStyle(fontSize: 22))))
              ])),
          const SizedBox(height: 14),
          Expanded(
              child: c.settingsTab == 'appearance'
                  ? AppearanceSettings(controller: c)
                  : c.settingsTab == 'layout'
                      ? GlassSurface(
                          child: Center(
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                              const Text('桌面，由你编排。',
                                  style: TextStyle(fontSize: 36)),
                              const SizedBox(height: 24),
                              Text('长按卡片进入编辑，移动、缩放、添加或移除。',
                                  style:
                                      TextStyle(fontSize: 22, color: s.muted)),
                              const SizedBox(height: 36),
                              FilledButton.icon(
                                  key: const ValueKey('start-edit'),
                                  onPressed: c.beginEdit,
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('编辑桌面布局')),
                              const SizedBox(height: 16),
                              TextButton(
                                  onPressed: c.resetLayout,
                                  child: const Text('恢复默认布局'))
                            ])))
                      : SourceSettings(controller: c)),
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
          flex: 2,
          child: ListView(children: [
            GlassSurface(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('显示模式', style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 18),
                  Row(children: [
                    for (final mode in [
                      ('system', Icons.brightness_auto_outlined, '跟随系统'),
                      ('light', Icons.light_mode_outlined, '浅色'),
                      ('dark', Icons.dark_mode_outlined, '深色')
                    ])
                      Expanded(
                          child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: OutlinedButton.icon(
                                  key: ValueKey('mode-${mode.$1}'),
                                  onPressed: () => c
                                      .setAppearance(a.copyWith(mode: mode.$1)),
                                  style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.all(20),
                                      side: BorderSide(
                                          color: a.mode == mode.$1
                                              ? s.accent
                                              : s.edge)),
                                  icon: Icon(mode.$2),
                                  label: Text(mode.$3,
                                      style: const TextStyle(fontSize: 19)))))
                  ])
                ])),
            const SizedBox(height: 16),
            GlassSurface(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('主题配色', style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 20),
                  Row(children: [
                    for (final preset in accentPresets)
                      Expanded(
                          child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: OutlinedButton(
                                  key: ValueKey('palette-${preset.id}'),
                                  onPressed: () => c.setAppearance(
                                      a.copyWith(palette: preset.id)),
                                  style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 18),
                                      side: BorderSide(
                                          color: a.palette == preset.id
                                              ? s.accent
                                              : s.edge)),
                                  child: Column(children: [
                                    CircleAvatar(
                                        radius: 23,
                                        backgroundColor: preset.seed,
                                        child: a.palette == preset.id
                                            ? const Icon(Icons.check,
                                                color: Colors.white)
                                            : null),
                                    const SizedBox(height: 12),
                                    Text(preset.name)
                                  ]))))
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    const Text('自定义颜色', style: TextStyle(fontSize: 19)),
                    const Spacer(),
                    Container(
                        width: 28,
                        height: 28,
                        color: a.palette == 'custom'
                            ? a.seed()
                            : const Color(0xFF38A4A0)),
                    const SizedBox(width: 16),
                    OutlinedButton(
                        key: const ValueKey('custom-color'),
                        onPressed: () => editCustomColor(context, c),
                        child: Text(a.custom)),
                    const SizedBox(width: 10),
                    const Text('HEX', style: TextStyle(fontSize: 15))
                  ])
                ])),
            const SizedBox(height: 16),
            GlassSurface(
                child: Column(children: [
              Row(children: [
                const Text('卡片圆角', style: TextStyle(fontSize: 22)),
                const Spacer(),
                Text('${a.radius.round()} px · 0 为直角',
                    style: TextStyle(color: s.muted, fontSize: 16))
              ]),
              Slider(
                  key: const ValueKey('radius-slider'),
                  value: a.radius,
                  min: 0,
                  max: 40,
                  divisions: 40,
                  onChanged: (v) =>
                      c.setAppearance(a.copyWith(radius: v), save: false),
                  onChangeEnd: (_) => c.persist())
            ])),
            const SizedBox(height: 16),
            GlassSurface(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: SwitchListTile(
                    key: const ValueKey('glass-switch'),
                    title: const Text('毛玻璃', style: TextStyle(fontSize: 22)),
                    subtitle: const Text('开启背景模糊，关闭后保留半透明材质'),
                    value: a.glass,
                    onChanged: (v) => c.setAppearance(a.copyWith(glass: v)))),
          ])),
      const SizedBox(width: 20),
      Expanded(
          child: GlassSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
            const Text('实时预览', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 24),
            Expanded(
                child: Center(
                    child: AspectRatio(
                        aspectRatio: 1.5,
                        child: GlassSurface(
                            child: Row(children: [
                          Expanded(
                              flex: 2,
                              child: Container(
                                  decoration: BoxDecoration(
                                      color: s.accent.withValues(alpha: .15),
                                      borderRadius:
                                          BorderRadius.circular(a.radius)),
                                  child: Icon(Icons.navigation_outlined,
                                      size: 72, color: s.accent))),
                          const SizedBox(width: 16),
                          Expanded(
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                Icon(Icons.music_note_outlined,
                                    size: 46, color: s.accent),
                                const SizedBox(height: 20),
                                Icon(Icons.cloud_outlined,
                                    size: 46, color: s.accent)
                              ]))
                        ]))))),
            const SizedBox(height: 20),
            Text('圆角、配色和模糊效果共用同一组样式。',
                style: TextStyle(color: s.muted, fontSize: 18, height: 1.5)),
            const SizedBox(height: 22),
            ValueListenableBuilder<Map<String, dynamic>>(
                valueListenable: c.native,
                builder: (context, n, _) => Column(children: [
                      SwitchListTile(
                          key: const ValueKey('hide-navigation'),
                          title: const Text('隐藏系统导航栏'),
                          value: n['hideNavigation'] == true,
                          onChanged: (v) =>
                              c.command('hide-navigation', enabled: v)),
                      SwitchListTile(
                          title: const Text('全局隐藏'),
                          subtitle: Text(n['globalNavigationGranted'] == true
                              ? '关闭时恢复原设置'
                              : '需要系统授权'),
                          value: n['globalNavigation'] == true,
                          onChanged: n['globalNavigationGranted'] == true
                              ? (v) =>
                                  c.command('global-navigation', enabled: v)
                              : null)
                    ])),
          ]))),
    ]);
  }
}

Future<void> editCustomColor(BuildContext context, LauncherController c) async {
  final input = TextEditingController(text: c.appearance.custom);
  String? error;
  await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
                  title: const Text('自定义主题色'),
                  content: TextField(
                      key: const ValueKey('hex-field'),
                      controller: input,
                      maxLength: 7,
                      decoration: InputDecoration(
                          labelText: '#RRGGBB', errorText: error)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消')),
                    FilledButton(
                        onPressed: () {
                          if (!RegExp(r'^#[0-9a-fA-F]{6}$')
                              .hasMatch(input.text)) {
                            setState(() => error = '请输入 # 加六位 HEX 色值');
                            return;
                          }
                          c.setAppearance(c.appearance
                              .copyWith(palette: 'custom', custom: input.text));
                          Navigator.pop(context);
                        },
                        child: const Text('应用'))
                  ])));
  input.dispose();
}

class SourceSettings extends StatelessWidget {
  final LauncherController controller;
  const SourceSettings({super.key, required this.controller});
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: controller.native,
          builder: (context, n, _) {
            final c = controller;
            Widget block(String title, String detail, Widget action) =>
                GlassSurface(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title, style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 18),
                      Text(detail,
                          style: TextStyle(
                              fontSize: 19,
                              height: 1.6,
                              color: SurfaceStyle.of(context).muted)),
                      const Spacer(),
                      action
                    ]));
            return GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 2.7,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                children: [
                  block(
                      '原车通信',
                      '${mapOf(n['vehicle'])['reason'] ?? '未连接原车服务'}',
                      TextButton.icon(
                          onPressed: () => c.command('refresh'),
                          icon: const Icon(Icons.refresh),
                          label: const Text('刷新连接'))),
                  block(
                      '音乐',
                      mapOf(n['media'])['authorized'] == true
                          ? '媒体访问已授权'
                          : '尚未授权媒体访问',
                      TextButton(
                          onPressed: () => c.command('media-access'),
                          child: const Text('授权媒体访问'))),
                  block(
                      '演示数据',
                      '仅用于离线验证，关闭后显示真实接入状态。',
                      SwitchListTile(
                          key: const ValueKey('demo-switch'),
                          title: const Text('开启演示'),
                          value: n['demo'] == true,
                          onChanged: (v) =>
                              c.command('demo-mode', enabled: v))),
                  block(
                      'Flutter 0.2.0',
                      'xyz.i4o.uni.launcher',
                      TextButton(
                          onPressed: () =>
                              c.command('open-official', value: 'settings'),
                          child: const Text('打开原车设置'))),
                ]);
          });
}
