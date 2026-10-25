import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';
import 'glass_surface.dart';

/// Installed-app identity is the key; labels may be duplicated or localized.
class IntegrationSettings extends StatelessWidget {
  final LauncherController controller;
  final Map<String, dynamic> native;
  const IntegrationSettings(
      {super.key, required this.controller, required this.native});
  Map<String, dynamic> map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context),
        nav = map(native['navigation']),
        prefs = map(native['integrationPreferences']);
    final apps = <String, String>{};
    for (final raw
        in native['apps'] is List ? native['apps'] as List : const []) {
      final app = map(raw),
          pkg =
              '${app['package'] ?? app['id']?.toString().split('/').first ?? ''}';
      if (pkg.isNotEmpty) {
        apps.putIfAbsent(pkg, () => controller.appName(app));
      }
    }
    Widget picker(String key, String label, String action, String selected) {
      final entries = {'auto': '自动选择', ...apps};
      if (!entries.containsKey(selected)) entries[selected] = '所选应用已卸载';
      return DropdownButtonFormField<String>(
          key: ValueKey(key),
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: entries.entries
              .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value,
                      maxLines: 1, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) {
            if (v != null) controller.command(action, value: v);
          });
    }

    return GlassSurface(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('导航与播放器', style: TextStyle(fontSize: Design.px(26))),
      SizedBox(height: Design.px(22)),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              picker('navigation-source', '导航应用', 'select-navigation',
                  '${nav['preferredPackage'] ?? 'auto'}'),
              SwitchListTile(
                  key: const ValueKey('embed-navigation'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('在地图卡片中显示导航'),
                  subtitle: Text('${nav['reason'] ?? '需要 Android 9 与车机嵌入权限'}'),
                  value: nav['enabled'] != false,
                  onChanged: (v) =>
                      controller.command('embed-navigation', enabled: v)),
              TextButton(
                  onPressed: () => controller.command('launch-navigation'),
                  child: const Text('打开导航应用')),
            ])),
        SizedBox(width: Design.px(30)),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              picker('media-source', '关联的音乐播放器', 'select-player',
                  '${prefs['mediaPackage'] ?? 'auto'}'),
              SizedBox(height: Design.px(16)),
              Text(
                  '选择网易云、QQ 音乐或原车音乐后，歌曲、封面、歌词和播放控制均跟随该应用。请先在播放器中播放一首歌曲并授权媒体访问。',
                  style: TextStyle(
                      color: s.muted, fontSize: Design.px(19), height: 1.6)),
              TextButton(
                  onPressed: () => controller.command('launch-player'),
                  child: const Text('打开关联播放器')),
            ]))
      ]),
      if (native['demo'] == true)
        Text('当前为演示模式；关闭演示数据后读取真实播放器与车辆信息。',
            style: TextStyle(color: s.accent, fontSize: Design.px(18))),
    ]));
  }
}
