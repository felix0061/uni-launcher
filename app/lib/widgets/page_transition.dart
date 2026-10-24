import 'package:flutter/material.dart';

/// Only the workspace moves; the header and dock remain fixed.
class DesktopPageTransition extends StatefulWidget {
  final int page;
  final String effect;
  final Widget child;
  const DesktopPageTransition(
      {super.key,
      required this.page,
      required this.effect,
      required this.child});
  @override
  State<DesktopPageTransition> createState() => _DesktopPageTransitionState();
}

class _DesktopPageTransitionState extends State<DesktopPageTransition> {
  int direction = 1;
  @override
  void didUpdateWidget(DesktopPageTransition old) {
    super.didUpdateWidget(old);
    if (old.page != widget.page) direction = widget.page > old.page ? 1 : -1;
  }

  @override
  Widget build(BuildContext context) {
    final disabled =
        widget.effect == 'none' || MediaQuery.disableAnimationsOf(context);
    if (disabled) return widget.child;
    return ClipRect(
        child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: [
            ...previous.map((w) => IgnorePointer(child: w)),
            if (current != null) current
          ]),
      transitionBuilder: (child, animation) {
        if (widget.effect == 'fade')
          return FadeTransition(opacity: animation, child: child);
        final incoming = child.key == ValueKey(widget.page);
        return SlideTransition(
            position: Tween<Offset>(
                    begin: Offset(
                        (incoming ? direction : -direction).toDouble(), 0),
                    end: Offset.zero)
                .animate(animation),
            child: child);
      },
      child: KeyedSubtree(key: ValueKey(widget.page), child: widget.child),
    ));
  }
}
