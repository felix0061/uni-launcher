import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';

/// Mirrors the seven XCSystemUIPlugin slots and account label from real reads.
class SystemStatusRow extends StatelessWidget {
  final Map<String, dynamic> status;
  const SystemStatusRow({super.key, required this.status});
  Map data(String key) => status[key] is Map ? status[key] as Map : const {};
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context), items = <Widget>[];
    void icon(String key, IconData value, String label,
        {String? text, bool accent = false, Widget? glyph}) {
      if (items.isNotEmpty) items.add(SizedBox(width: Design.px(18)));
      items.add(Tooltip(
          message: label,
          child: Semantics(
              label: label,
              child: Row(
                  key: ValueKey('status-$key'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    glyph ??
                        Icon(value,
                            size: Design.px(24),
                            color: accent ? s.accent : s.muted),
                    if (text != null && text.isNotEmpty) ...[
                      SizedBox(width: Design.px(5)),
                      Text(text,
                          style: TextStyle(
                              fontSize: Design.px(18), color: s.muted))
                    ],
                  ]))));
    }

    final net = data('network'),
        bt = data('bluetooth'),
        usb = data('usb'),
        wpc = data('charging'),
        dvr = data('dvr'),
        msg = data('messages'),
        account = data('account');
    if (net['mobileKnown'] == true && net['wifi'] != true) {
      final level = (net['mobileLevel'] as num?)?.toInt() ?? -1;
      icon(
          'mobile',
          net['mobileEnabled'] == true && level > 0
              ? Icons.signal_cellular_alt
              : Icons.signal_cellular_connected_no_internet_0_bar,
          '移动网络 ${net['mobileLabel'] ?? ''}，信号${level < 0 ? '未知' : level}',
          text: net['mobileLabel']?.toString(),
          glyph: net['mobileEnabled'] == true && level >= 0
              ? SignalBars(level: level, color: s.muted)
              : null);
    }
    if (net['hotspot'] == true) {
      icon('hotspot', Icons.link, '热点已开启', text: net['clients']?.toString());
    } else if (net['wifi'] == true) {
      final level = (net['wifiLevel'] as num?)?.toInt() ?? 4;
      icon(
          'wifi',
          switch (level) {
            0 => Icons.signal_wifi_0_bar,
            1 => Icons.network_wifi_1_bar,
            2 => Icons.network_wifi_2_bar,
            3 => Icons.network_wifi_3_bar,
            _ => Icons.wifi
          },
          'Wi-Fi 已连接');
    }
    if (bt['known'] == true && bt['enabled'] == true)
      icon(
          'bluetooth',
          bt['connected'] == true ? Icons.bluetooth_connected : Icons.bluetooth,
          bt['connected'] == true ? '蓝牙已连接' : '蓝牙已开启',
          accent: bt['connected'] == true);
    if (wpc['visible'] == true)
      icon(
          'charging',
          wpc['error'] == true
              ? Icons.battery_alert_outlined
              : Icons.battery_charging_full,
          wpc['error'] == true ? '无线充电异常' : '无线充电',
          accent: wpc['error'] != true);
    if (usb['visible'] == true)
      icon('usb', Icons.usb, 'USB 已连接',
          text: (usb['count'] as num? ?? 0) > 1 ? '${usb['count']}' : null);
    if (dvr['visible'] == true)
      icon(
          'dvr',
          dvr['recording'] == true
              ? Icons.videocam_outlined
              : Icons.videocam_off_outlined,
          dvr['recording'] == true ? '行车记录仪正在录制' : '行车记录仪已暂停',
          accent: dvr['recording'] == true);
    if ((msg['count'] as num? ?? 0) > 0)
      icon('messages', Icons.mark_email_unread_outlined, '未读消息 ${msg['count']}',
          text: '${msg['count']}');
    if (account['known'] == true) {
      if (items.isNotEmpty) items.add(SizedBox(width: Design.px(22)));
      items.add(ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Design.px(220)),
          child: Text(
              account['loggedIn'] == true
                  ? '${account['name'] ?? '已登录'}'
                  : '未登录',
              key: const ValueKey('status-account'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: Design.px(19), color: s.muted))));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: items);
  }
}

class SignalBars extends StatelessWidget {
  final int level;
  final Color color;
  const SignalBars({super.key, required this.level, required this.color});
  @override
  Widget build(BuildContext context) => SizedBox(
      height: Design.px(24),
      child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (int i = 0; i < 4; i++)
              Container(
                  width: Design.px(4),
                  height: Design.px(7 + i * 5),
                  margin: EdgeInsets.only(right: Design.px(2)),
                  color: i < level ? color : color.withValues(alpha: .2)),
          ]));
}
