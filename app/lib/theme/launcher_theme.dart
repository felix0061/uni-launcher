import 'package:flutter/material.dart';
import '../model/appearance.dart';

class SurfaceStyle extends ThemeExtension<SurfaceStyle> {
  final bool dark, glass;
  final double radius;
  final Color accent, seed, text, muted, surface, edge;
  const SurfaceStyle(
      {required this.dark,
      required this.glass,
      required this.radius,
      required this.accent,
      required this.seed,
      required this.text,
      required this.muted,
      required this.surface,
      required this.edge});
  factory SurfaceStyle.from(Appearance a, bool systemDark) {
    final dark = a.isDark(systemDark);
    return SurfaceStyle(
        dark: dark,
        glass: a.glass,
        radius: a.radius,
        accent: a.accent(dark),
        seed: a.seed(),
        text: dark ? const Color(0xFFE9F4F4) : const Color(0xFF18312D),
        muted: dark ? const Color(0xFFA5BBBD) : const Color(0xFF607E77),
        surface: dark ? const Color(0xA61A3039) : const Color(0xAAFAFFFD),
        edge: dark ? const Color(0x24D9F8F4) : const Color(0xB3FFFFFF));
  }
  static SurfaceStyle of(BuildContext c) =>
      Theme.of(c).extension<SurfaceStyle>()!;
  @override
  SurfaceStyle copyWith() => this;
  @override
  SurfaceStyle lerp(covariant SurfaceStyle? other, double t) => other ?? this;
}

ThemeData launcherTheme(SurfaceStyle s) => ThemeData(
      useMaterial3: true,
      brightness: s.dark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
              seedColor: s.seed,
              brightness: s.dark ? Brightness.dark : Brightness.light)
          .copyWith(primary: s.accent),
      scaffoldBackgroundColor:
          s.dark ? const Color(0xFF142832) : const Color(0xFFDDEAE6),
      textTheme: Typography.material2021()
          .black
          .apply(bodyColor: s.text, displayColor: s.text),
      tooltipTheme:
          const TooltipThemeData(waitDuration: Duration(milliseconds: 800)),
      extensions: [s],
    );
