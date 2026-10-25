import 'package:flutter/material.dart';
import 'package:uni_launcher/model/appearance.dart';
import 'package:uni_launcher/theme/launcher_theme.dart';
import 'package:uni_launcher/widgets/glass_surface.dart';
import 'package:uni_launcher/widgets/vehicle_cards.dart';

enum VehicleGalleryState { live, disconnected, partial }

const vehicleGalleryNow = 1800000000000;
const vehicleGalleryBoardKey = ValueKey('vehicle-gallery-board');
const vehicleGalleryBoardSize = Size(1600, 900);

void main() => runApp(const VehicleCardGallery());

/// Deliberately confined to verification. Never used by the launcher/demo mode.
Map<String, dynamic> vehicleGalleryFixture(
    [VehicleGalleryState state = VehicleGalleryState.live]) {
  final fields = <String, dynamic>{
    for (final item in const [
      ('batteryPercent', 95.0, '%'),
      ('pm25', 12.0, 'µg/m³'),
      ('aqi', 28.0, ''),
      ('speed', 62.5, 'km/h'),
      ('odometer', 18764.0, 'km'),
      ('range', 426.0, 'km'),
      ('maintenanceMileage', 3200.0, 'km'),
    ])
      item.$1: <String, dynamic>{
        'value': item.$2,
        'unit': item.$3,
        'valid': true,
        'unitVerified': true,
        'updatedAtMs': vehicleGalleryNow - 1000,
        'source': 'gallery-example',
      },
  };
  for (final item in const [
    ('driveMode', 'HYBRID'),
    ('energyFlow', 'ELECTRIC_DRIVE')
  ]) {
    fields[item.$1] = {
      'value': item.$2,
      'valid': true,
      'updatedAtMs': vehicleGalleryNow - 1000
    };
  }
  if (state == VehicleGalleryState.partial) {
    fields['driveMode']['updatedAtMs'] = vehicleGalleryNow - 6000;
    fields['energyFlow']['valid'] = false;
    fields['batteryPercent']['updatedAtMs'] = vehicleGalleryNow - 6000;
    fields['aqi']['valid'] = false;
    fields['speed']['updatedAtMs'] = vehicleGalleryNow - 6000;
    fields['range']['unitVerified'] = false;
    fields['range']['sampleValid'] = true;
    fields['range']['valid'] = false;
    fields['maintenanceMileage']['valid'] = false;
  }
  return {
    'demo': false,
    'vehicle': {
      'connected': state != VehicleGalleryState.disconnected,
      'fields': fields,
    },
  };
}

/// Standalone 1920 × 1080 design sheet, without dock, map, gateway or overlays.
/// Both regular 4×3 and minimum 3×2 cards use the production content/surface.
class VehicleCardGallery extends StatelessWidget {
  final Appearance appearance;
  final VehicleGalleryState state;
  // Widget-test exports can supply a locally loaded CJK review font.
  final String? fontFamily;
  const VehicleCardGallery(
      {super.key,
      this.appearance = const Appearance(mode: 'dark'),
      this.state = VehicleGalleryState.live,
      this.fontFamily});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.from(appearance, true);
    final theme = launcherTheme(s);
    final native = vehicleGalleryFixture(state);
    Widget card(String type) => switch (type) {
          'battery' =>
            BatteryCard(native: native, nowMs: () => vehicleGalleryNow),
          'air' =>
            AirQualityCard(native: native, nowMs: () => vehicleGalleryNow),
          _ => DrivingInfoCard(native: native, nowMs: () => vehicleGalleryNow),
        };
    Widget row(bool compact) =>
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final type in ['battery', 'air', 'vehicle']) ...[
            if (type != 'battery') const SizedBox(width: 28),
            Expanded(
                child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                        width: compact ? 355 : double.infinity,
                        height: compact ? 580 / 3 : 300,
                        child: GlassSurface(
                            padding: EdgeInsets.zero, child: card(type))))),
          ],
        ]);
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fontFamily == null
            ? theme
            : theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: fontFamily)),
        home: Scaffold(
            body: SizedBox.expand(
                child: FittedBox(
                    fit: BoxFit.contain,
                    child: RepaintBoundary(
                        key: vehicleGalleryBoardKey,
                        child: SizedBox(
                            width: vehicleGalleryBoardSize.width,
                            height: vehicleGalleryBoardSize.height,
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: s.dark
                                            ? [
                                                const Color(0xff112b30),
                                                const Color(0xff0e1920)
                                              ]
                                            : [
                                                const Color(0xffd9eae1),
                                                const Color(0xfff1f4eb)
                                              ])),
                                child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        48, 36, 48, 32),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text('LYNK & CO / 05  ·  车辆卡片',
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  letterSpacing: 2,
                                                  color: s.muted)),
                                          const SizedBox(height: 12),
                                          Row(children: [
                                            const Text('车辆信息，一眼可读。',
                                                style: TextStyle(
                                                    fontSize: 34,
                                                    fontWeight:
                                                        FontWeight.w400)),
                                            const Spacer(),
                                            Text(
                                                '${s.dark ? '深色' : '浅色'} · ${switch (state) {
                                                  VehicleGalleryState.live =>
                                                    '有效读数',
                                                  VehicleGalleryState
                                                        .disconnected =>
                                                    '断连',
                                                  VehicleGalleryState.partial =>
                                                    '独立字段状态',
                                                }} · 圆角 ${appearance.radius.round()} · ${s.glass ? '毛玻璃' : '半透明'}',
                                                style: TextStyle(
                                                    fontSize: 17,
                                                    color: s.muted)),
                                          ]),
                                          const SizedBox(height: 10),
                                          Text('示例数据 · 仅供样式评审，不代表车辆当前读数',
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  color: s.muted)),
                                          const SizedBox(height: 26),
                                          Text('常规 / 4 × 3',
                                              style: TextStyle(
                                                  fontSize: 17,
                                                  color: s.muted)),
                                          const SizedBox(height: 12),
                                          row(false),
                                          const SizedBox(height: 26),
                                          Text('紧凑 / 最小 3 × 2',
                                              style: TextStyle(
                                                  fontSize: 17,
                                                  color: s.muted)),
                                          const SizedBox(height: 12),
                                          row(true),
                                          const Spacer(),
                                          Text(
                                              '模式与能量流独立读取 · 不推断外接充电与纯电续航 · 速度和距离保留已确认的单位',
                                              style: TextStyle(
                                                  fontSize: 17,
                                                  color: s.muted)),
                                        ])))))))));
  }
}
