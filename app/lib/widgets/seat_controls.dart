import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../model/seat_control.dart';
import '../theme/design_tokens.dart';
import '../theme/launcher_theme.dart';
import 'uni_icon.dart';

class SeatControls extends StatelessWidget {
  final LauncherController controller;
  final Map<String, dynamic> native;
  const SeatControls(
      {super.key, required this.controller, required this.native});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context), demo = native['demo'] == true;
    final writable = ['driverHeat', 'driverVent', 'passengerHeat']
        .any((key) => SeatControlState.fromNative(native, key).writable);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: Design.px(28)),
      Divider(height: 1, color: s.edge),
      SizedBox(height: Design.px(24)),
      Row(children: [
        Text('座椅舒适',
            style: TextStyle(
                fontSize: Design.px(24), fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(demo || writable ? '主驾加热 / 通风互斥' : '只读状态 · 控制待实车确认',
            style: TextStyle(fontSize: Design.px(18), color: s.muted)),
      ]),
      SizedBox(height: Design.px(6)),
      for (final control in [
        ('driverHeat', 'seat-heat', 'left', '主驾座椅加热'),
        ('driverVent', 'seat-vent', 'left', '主驾通风'),
        ('passengerHeat', 'seat-heat', 'right', '副驾加热'),
      ])
        _row(context, control),
      SizedBox(height: Design.px(18)),
      Text(
          demo
              ? '示例档位 · 不控制车辆'
              : writable
                  ? '点击档位调整座椅舒适功能'
                  : '有读数时显示当前档位；操作请使用空调面板',
          style: TextStyle(fontSize: Design.px(17), color: s.muted)),
    ]);
  }

  Widget _row(BuildContext context, (String, String, String, String) control) {
    final s = SurfaceStyle.of(context);
    final state = SeatControlState.fromNative(native, control.$1);
    return Padding(
        padding: EdgeInsets.only(top: Design.px(12)),
        child: Row(children: [
          UniIcon(control.$2, size: Design.px(30), color: s.accent),
          SizedBox(width: Design.px(14)),
          Text(control.$4, style: TextStyle(fontSize: Design.px(23))),
          if (state.level == null) ...[
            SizedBox(width: Design.px(12)),
            Text('—',
                key: ValueKey('seat-unknown-${control.$1}'),
                style: TextStyle(color: s.muted)),
          ],
          const Spacer(),
          SizedBox(
              width: Design.px(520),
              child: Row(children: [
                for (int level = 0; level <= 3; level++)
                  Expanded(
                      child: Padding(
                    padding:
                        EdgeInsets.only(left: level == 0 ? 0 : Design.px(12)),
                    child: SizedBox(
                        height: Design.px(64),
                        child: Semantics(
                          selected: state.level == level,
                          child: OutlinedButton(
                            key: ValueKey('seat-${control.$1}-$level'),
                            style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor:
                                    state.level == level ? s.accent : s.soft,
                                foregroundColor: state.level == level
                                    ? s.accentText
                                    : s.text,
                                side: BorderSide(
                                    color: state.level == level
                                        ? Colors.transparent
                                        : s.edge)),
                            onPressed: state.writable
                                ? () => controller.command(control.$2,
                                    zone: control.$3, value: '$level')
                                : null,
                            child: Text(level == 0 ? '关闭' : '${level}档',
                                style: TextStyle(fontSize: Design.px(22))),
                          ),
                        )),
                  )),
              ])),
        ]));
  }
}
