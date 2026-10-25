import 'package:flutter/material.dart';

class AccentPreset {
  final String id, name;
  final Color seed, dark, light;
  const AccentPreset(this.id, this.name, this.seed, this.dark, this.light);
}

const accentPresets = [
  AccentPreset(
      'mint', '青屿', Color(0xFF31B9A2), Color(0xFF71E4CE), Color(0xFF087568)),
  AccentPreset(
      'blue', '冰川', Color(0xFF4B92DE), Color(0xFF8FC8FF), Color(0xFF245F9E)),
  AccentPreset(
      'violet', '鸢尾', Color(0xFF9570D5), Color(0xFFCEB5FF), Color(0xFF7550A4)),
  AccentPreset(
      'amber', '琥珀', Color(0xFFD49A47), Color(0xFFF4CF8A), Color(0xFF8B5E1E)),
  AccentPreset(
      'rose', '玫瑰', Color(0xFFCB748A), Color(0xFFF4B1C4), Color(0xFF98465F)),
];

class Appearance {
  static const defaultDesktopName = 'LYNK & CO / 05';
  static String normalizeDesktopName(Object? value) {
    final name =
        value is String ? value.replaceAll(RegExp(r'[\r\n]'), ' ').trim() : '';
    return name.isEmpty
        ? defaultDesktopName
        : String.fromCharCodes(name.runes.take(24));
  }

  final String mode, palette, custom, pageTransition, desktopName;
  final double radius;
  final bool glass;
  const Appearance(
      {this.desktopName = defaultDesktopName,
      this.mode = 'system',
      this.palette = 'mint',
      this.custom = '#38A4A0',
      this.radius = 28,
      this.glass = false,
      this.pageTransition = 'none'});
  factory Appearance.fromJson(Map<String, dynamic> json) => Appearance(
        desktopName: normalizeDesktopName(json['desktopName']),
        mode: ['system', 'light', 'dark'].contains(json['mode'])
            ? json['mode']
            : 'system',
        palette: [...accentPresets.map((p) => p.id), 'custom']
                .contains(json['palette'])
            ? json['palette']
            : 'mint',
        custom: RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch('${json['custom']}')
            ? json['custom']
            : '#38A4A0',
        radius: json['radius'] is num
            ? (json['radius'] as num).toDouble().clamp(0, 40)
            : 28,
        glass: json['glass'] == true,
        pageTransition:
            ['none', 'fade', 'slide'].contains(json['pageTransition'])
                ? json['pageTransition']
                : 'none',
      );
  Appearance copyWith(
          {String? desktopName,
          String? mode,
          String? palette,
          String? custom,
          double? radius,
          bool? glass,
          String? pageTransition}) =>
      Appearance(
          desktopName: normalizeDesktopName(desktopName ?? this.desktopName),
          mode: mode ?? this.mode,
          palette: palette ?? this.palette,
          custom: custom ?? this.custom,
          radius: (radius ?? this.radius).clamp(0, 40),
          glass: glass ?? this.glass,
          pageTransition: pageTransition ?? this.pageTransition);
  Map<String, dynamic> toJson() => {
        'desktopName': desktopName,
        'mode': mode,
        'palette': palette,
        'custom': custom,
        'radius': radius.round(),
        'glass': glass,
        'pageTransition': pageTransition
      };
  bool isDark(bool systemDark) =>
      mode == 'dark' || (mode == 'system' && systemDark);
  Color seed() => palette == 'custom'
      ? Color(0xFF000000 | int.parse(custom.substring(1), radix: 16))
      : accentPresets.firstWhere((p) => p.id == palette).seed;
  Color accent(bool dark) {
    if (palette == 'custom')
      return Color.lerp(seed(), dark ? Colors.white : Colors.black, .42)!;
    final p = accentPresets.firstWhere((p) => p.id == palette);
    return dark ? p.dark : p.light;
  }
}
