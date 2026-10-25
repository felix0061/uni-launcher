import 'package:flutter/material.dart';

/// Keeps every desktop page mounted (including the Android map surface) while
/// animating the Flutter card layer. This avoids recreating the navigation app
/// and still gives the familiar launcher fade/slide transitions on car builds.
class DesktopPageStack extends StatelessWidget {
  final int page;
  final String effect;
  final List<Widget> children;
  const DesktopPageStack(
      {super.key,
      required this.page,
      required this.effect,
      required this.children});

  @override
  Widget build(BuildContext context) {
    final disabled = effect == 'none' ||
        MediaQuery.disableAnimationsOf(context) ||
        children.length < 2;
    if (disabled) return IndexedStack(index: page, children: children);
    // Keep the Android map surface mounted, but animate only one inexpensive
    // property. The previous slide+scale+opacity stack forced three composited
    // layers for every page and was visibly slow on the IP753 GPU.
    const duration = Duration(milliseconds: 220);
    final order = <int>[
      for (var i = 0; i < children.length; i++)
        if (i != page) i,
      page,
    ];
    return ClipRect(
        child: Stack(fit: StackFit.expand, children: [
      for (final i in order)
        Positioned.fill(
            key: ValueKey('desktop-motion-page-$i'),
            child: IgnorePointer(
                ignoring: i != page,
                child: ExcludeSemantics(
                    excluding: i != page,
                    child: TickerMode(
                        enabled: i == page,
                        child: RepaintBoundary(
                            child: effect == 'slide'
                                ? AnimatedSlide(
                                    duration: duration,
                                    curve: Curves.easeOutCubic,
                                    offset: Offset(
                                        i == page ? 0 : (i < page ? -1 : 1), 0),
                                    child: children[i])
                                : AnimatedOpacity(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    opacity: i == page ? 1 : 0,
                                    child: children[i])))))),
    ]));
  }
}

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
