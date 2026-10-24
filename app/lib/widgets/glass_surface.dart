import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/launcher_theme.dart';

class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? radius;
  const GlassSurface(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(22),
      this.radius});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    final shape = BorderRadius.circular(radius ?? s.radius);
    final content = DecoratedBox(
        decoration: BoxDecoration(
            color: s.surface,
            borderRadius: shape,
            border: Border.all(color: s.edge)),
        child: Material(
            type: MaterialType.transparency,
            child: Padding(padding: padding, child: child)));
    return ClipRRect(
        borderRadius: shape,
        child: s.glass
            ? BackdropFilter(
                key: const ValueKey('glass-filter'),
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: content)
            : content);
  }
}

class IconAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap, onLongPress;
  final bool active;
  final double size;
  const IconAction(
      {super.key,
      required this.icon,
      required this.label,
      this.onTap,
      this.onLongPress,
      this.active = false,
      this.size = 48});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return Tooltip(
        message: label,
        child: Semantics(
            button: true,
            label: label,
            child: GestureDetector(
                onLongPress: onLongPress,
                child: SizedBox(
                    width: size,
                    height: size,
                    child: IconButton(
                      onPressed: onTap,
                      icon: Icon(icon, size: 24),
                      style: IconButton.styleFrom(
                          foregroundColor: active ? s.accent : s.text,
                          disabledForegroundColor:
                              s.muted.withValues(alpha: .35),
                          backgroundColor: active
                              ? s.accent.withValues(alpha: .12)
                              : Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(s.radius * .65))),
                    )))));
  }
}

class CardHeading extends StatelessWidget {
  final String title, source;
  final IconData icon;
  const CardHeading(this.title, this.source, this.icon, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return Row(children: [
      Icon(icon, size: 21, color: s.accent),
      const SizedBox(width: 10),
      Expanded(
          child: Text(title,
              style: const TextStyle(fontSize: 22),
              maxLines: 1,
              overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 12),
      Flexible(
          child: Text(source,
              style: TextStyle(fontSize: 14, color: s.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis))
    ]);
  }
}
