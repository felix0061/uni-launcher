import 'package:flutter/material.dart';
import '../theme/launcher_theme.dart';

class SceneBackground extends StatelessWidget {
  final Widget child;
  const SceneBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return DecoratedBox(
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0, .63, 1],
                colors: s.dark
                    ? const [
                        Color(0xFF0E1920),
                        Color(0xFF273E46),
                        Color(0xFF172A34)
                      ]
                    : const [
                        Color(0xFFE1ECE7),
                        Color(0xFFD4E1E0),
                        Color(0xFFE9EEF0)
                      ])),
        child: DecoratedBox(
            decoration: BoxDecoration(
                gradient: RadialGradient(
                    center: s.dark
                        ? const Alignment(-.76, -.92)
                        : const Alignment(-.84, -.64),
                    radius: .9,
                    colors: [
                  s.seed.withValues(alpha: s.dark ? .20 : .16),
                  s.seed.withValues(alpha: 0)
                ])),
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: RadialGradient(
                        center: const Alignment(.7, .36),
                        radius: .8,
                        colors: [
                      (s.dark
                              ? const Color(0xFF79A2B7)
                              : const Color(0xFF9FC0D5))
                          .withValues(alpha: s.dark ? .24 : .42),
                      const Color(0x0079A2B7)
                    ])),
                child: child)));
  }
}
