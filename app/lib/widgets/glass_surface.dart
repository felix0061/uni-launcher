import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/launcher_theme.dart';
import '../theme/design_tokens.dart';
import 'uni_icon.dart';

enum SurfaceTone { normal, strong, soft }

class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? radius;
  final SurfaceTone tone;
  final Color? borderColor;
  final bool shadow;
  const GlassSurface(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(22),
      this.radius,
      this.tone = SurfaceTone.normal,
      this.borderColor,
      this.shadow = true});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context),
        shape = BorderRadius.circular(radius ?? s.radius);
    final content = DecoratedBox(
        decoration: BoxDecoration(
            color: switch (tone) {
              SurfaceTone.normal => s.surface,
              SurfaceTone.strong => s.strong,
              SurfaceTone.soft => s.soft
            },
            borderRadius: shape,
            border: Border.all(color: borderColor ?? s.edge)),
        child: Material(
            type: MaterialType.transparency,
            child: Padding(padding: padding, child: child)));
    return DecoratedBox(
        decoration: BoxDecoration(
            borderRadius: shape,
            boxShadow: shadow
                ? [
                    BoxShadow(
                        color: s.shadow,
                        offset: Offset(0, Design.px(16)),
                        blurRadius: Design.px(44))
                  ]
                : null),
        child: ClipRRect(
            borderRadius: shape,
            child: s.glass
                ? BackdropFilter(
                    key: const ValueKey('glass-filter'),
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: content)
                : content));
  }
}

class IconAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap, onLongPress;
  final bool active, solid, soft;
  final double size, iconSize;
  final Color? foregroundColor;
  const IconAction(
      {super.key,
      required this.icon,
      required this.label,
      this.onTap,
      this.onLongPress,
      this.active = false,
      this.solid = false,
      this.soft = false,
      this.size = 48,
      this.iconSize = 24,
      this.foregroundColor});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context),
        enabled = onTap != null || onLongPress != null;
    final fg = !enabled
        ? s.muted.withValues(alpha: .35)
        : solid
            ? s.accentText
            : active
                ? s.accent
                : s.text;
    final effectiveColor = enabled ? (foregroundColor ?? fg) : fg;
    return Tooltip(
        message: label,
        child: Semantics(
            button: true,
            label: label,
            enabled: enabled,
            child: SizedBox(
                width: size,
                height: size,
                child: Material(
                    color: solid
                        ? (enabled ? s.accent : s.soft)
                        : (soft ? s.soft : Colors.transparent),
                    borderRadius: BorderRadius.circular(s.controlRadius),
                    child: InkWell(
                        borderRadius: BorderRadius.circular(s.controlRadius),
                        onTap: onTap,
                        onLongPress: onLongPress,
                        child: Center(
                            child: DesignIcon(icon,
                                size: iconSize, color: effectiveColor)))))));
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
      DesignIcon(icon, size: Design.px(27), color: s.accent),
      SizedBox(width: Design.px(12)),
      Expanded(
          child: Text(title,
              style: TextStyle(fontSize: Design.px(25)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis)),
      SizedBox(width: Design.px(14)),
      Flexible(
          child: Text(source,
              style: TextStyle(fontSize: Design.px(16), color: s.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis))
    ]);
  }
}

class DesignToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const DesignToggle(
      {super.key, required this.label, required this.value, this.onChanged});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return Semantics(
        label: label,
        toggled: value,
        enabled: onChanged != null,
        child: InkWell(
            onTap: onChanged == null ? null : () => onChanged!(!value),
            borderRadius: BorderRadius.circular(s.controlRadius),
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: Design.px(88),
                height: Design.px(48),
                padding: EdgeInsets.all(Design.px(6)),
                decoration: BoxDecoration(
                    color: value ? s.accent : s.soft,
                    border:
                        Border.all(color: value ? Colors.transparent : s.edge),
                    borderRadius: BorderRadius.circular(s.controlRadius)),
                child: Align(
                    alignment:
                        value ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                        width: Design.px(34),
                        height: Design.px(34),
                        decoration: BoxDecoration(
                            color: value ? s.accentText : s.muted,
                            borderRadius:
                                BorderRadius.circular(s.radius * .42)))))));
  }
}
