import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controller/launcher_controller.dart';
import '../model/vehicle_data.dart';
import '../model/vehicle_card_data.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';
import 'card_content.dart' show TireDiagram;

class VehicleReadout extends StatelessWidget {
  final LauncherController controller;
  final Map<String, dynamic> native;
  const VehicleReadout(
      {super.key, required this.controller, required this.native});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context),
        vehicle =
            native['vehicle'] is Map ? native['vehicle'] as Map : const {};
    return SingleChildScrollView(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: Design.px(280), child: TireDiagram(native: native)),
      Center(
          child: Text(
              vehicle['connected'] == true ? '胎压原始值 · 单位待实车核对' : '等待车辆数据',
              style: TextStyle(color: s.muted, fontSize: Design.px(18)))),
      SizedBox(height: Design.px(20)),
      Wrap(spacing: Design.px(18), runSpacing: Design.px(14), children: [
        for (final item in const [
          ('left', '主驾温度', '°'),
          ('right', '副驾温度', '°'),
          ('fan', '风量', ''),
          ('driverHeat', '主驾加热', '档'),
          ('driverVent', '主驾通风', '档'),
          ('passengerHeat', '副驾加热', '档'),
          ('batteryPercent', '动力电池', '%'),
          ('pm25', '车内 PM2.5', ' µg/m³'),
          ('aqi', '车内 AQI', ''),
          ('speed', '车速', ''),
          ('odometer', '里程', ''),
          ('range', '续航', '')
        ])
          SizedBox(
              width: Design.px(235),
              child: Row(children: [
                Expanded(
                    child: Text(item.$2,
                        style: TextStyle(
                            color: s.muted, fontSize: Design.px(19)))),
                Text(
                    '${VehicleField.fromNative(native, item.$1).display(decimals: item.$3 == '°' ? 1 : 0)}${item.$3}',
                    style: TextStyle(fontSize: Design.px(23)))
              ]))
      ]),
      SizedBox(height: Design.px(22)),
      for (final item in const [
        ('driveMode', '驾驶模式'),
        ('hybridSelected', '混动选择'),
        ('energyFlow', '能量流')
      ])
        Padding(
            padding: EdgeInsets.only(bottom: Design.px(10)),
            child: Row(children: [
              Text(item.$2, style: TextStyle(color: s.muted)),
              const Spacer(),
              Text(vehicleStatusLabel(native, item.$1)),
            ])),
      Text('${vehicle['reason'] ?? '等待原车车辆服务'}',
          style:
              TextStyle(fontSize: Design.px(18), color: s.muted, height: 1.6)),
      Text('未获得有效读数或单位的项目显示 —',
          style: TextStyle(fontSize: Design.px(17), color: s.muted)),
      Wrap(alignment: WrapAlignment.end, spacing: Design.px(12), children: [
        TextButton(
            key: const ValueKey('copy-vehicle-data'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(
                  text: const JsonEncoder.withIndent('  ').convert(vehicle)));
              if (context.mounted)
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('车辆读取结果已复制')));
            },
            child: const Text('复制读取结果')),
        TextButton(
            onPressed: () => controller.command('refresh'),
            child: const Text('刷新读取')),
        FilledButton(
            onPressed: () =>
                controller.command('open-official', value: 'vehicle'),
            child: const Text('打开原车车辆')),
      ]),
    ]));
  }
}
