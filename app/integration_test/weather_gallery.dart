import 'package:flutter/material.dart';
import 'package:uni_launcher/model/weather_condition.dart';
import 'package:uni_launcher/widgets/weather_icon.dart';

/// Verification-only atlas, not a separate installed application.
class WeatherGallery extends StatelessWidget {
  final bool night;
  const WeatherGallery({super.key, required this.night});
  @override
  Widget build(BuildContext context) => Material(
      color: night ? const Color(0xff16232b) : const Color(0xffedf5f1),
      child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(children: [
            Text(
                '天气图标 · ${night ? '夜间' : '日间'} · ${WeatherKind.values.length} 种状态',
                style: TextStyle(
                    fontSize: 30,
                    color: night ? Colors.white : const Color(0xff182d29))),
            const SizedBox(height: 24),
            Expanded(
                child: GridView.count(
                    crossAxisCount: 8,
                    childAspectRatio: 1.35,
                    children: [
                  for (final k in WeatherKind.values)
                    Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          WeatherIcon(
                              condition: k,
                              night: night,
                              color: night
                                  ? const Color(0xff71e4ce)
                                  : const Color(0xff087568),
                              size: 70),
                          const SizedBox(height: 5),
                          Text(k.label,
                              style: TextStyle(
                                  color: night
                                      ? Colors.white
                                      : const Color(0xff182d29),
                                  fontSize: 18))
                        ])
                ]))
          ])));
}
