import 'package:flutter/material.dart';

/// A native Android Surface must stay still while Flutter animates its cached
/// preview. Showing it only after motion settles avoids hybrid-composition
/// relocation and a newly created black Surface covering the incoming page.
class DesktopMotionScope extends InheritedWidget {
  final bool moving;
  const DesktopMotionScope(
      {super.key, required this.moving, required super.child});
  static bool movingOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DesktopMotionScope>()
          ?.moving ??
      false;
  @override
  bool updateShouldNotify(DesktopMotionScope oldWidget) =>
      moving != oldWidget.moving;
}

/// Keeps every desktop page mounted (including the Android map surface) while
/// animating the Flutter card layer. This avoids recreating the navigation app
/// and still gives the familiar launcher fade/slide transitions on car builds.
class DesktopPageStack extends StatefulWidget {
  final int page;
  final String effect;
  final List<Widget> children;
  const DesktopPageStack(
      {super.key,
      required this.page,
      required this.effect,
      required this.children});

  @override
  State<DesktopPageStack> createState() => _DesktopPageStackState();
}

class _DesktopPageStackState extends State<DesktopPageStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  late int _fromPage, _toPage;
  int _direction = 1;

  int _bounded(int page) =>
      widget.children.isEmpty ? 0 : page.clamp(0, widget.children.length - 1);

  bool get _motionDisabled =>
      widget.effect == 'none' ||
      MediaQuery.disableAnimationsOf(context) ||
      widget.children.length < 2;

  @override
  void initState() {
    super.initState();
    _fromPage = _toPage = _bounded(widget.page);
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _fromPage = _toPage);
      }
    });
  }

  @override
  void didUpdateWidget(DesktopPageStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _bounded(widget.page);
    if (oldWidget.page != widget.page) {
      _fromPage = _bounded(oldWidget.page);
      _toPage = target;
      _direction = _toPage > _fromPage ? 1 : -1;
      if (_motionDisabled) {
        _controller.stop();
        _fromPage = _toPage;
      } else {
        _controller.duration =
            Duration(milliseconds: widget.effect == 'fade' ? 120 : 150);
        _controller.forward(from: 0);
      }
    } else if (_motionDisabled || oldWidget.effect != widget.effect) {
      _controller.stop();
      _fromPage = _toPage = target;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionDisabled && _controller.isAnimating) {
      _controller.stop();
      _fromPage = _toPage = _bounded(widget.page);
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();
    final moving = !_motionDisabled && _fromPage != _toPage;
    return ClipRect(
        child: Stack(fit: StackFit.expand, children: [
      for (var i = 0; i < widget.children.length; i++)
        Positioned.fill(
            key: ValueKey('desktop-motion-page-$i'),
            child: Offstage(
                // Painting and laying out both card-heavy pages made
                // Android 9 miss frames. The incoming workspace alone
                // carries the short transition over the stable scene.
                offstage: i != _toPage,
                child: IgnorePointer(
                    ignoring: i != _toPage,
                    child: ExcludeSemantics(
                        excluding: i != _toPage,
                        child: TickerMode(
                            enabled: i == _toPage,
                            child: RepaintBoundary(
                                child: _animatedPage(i, moving))))))),
    ]));
  }

  Widget _animatedPage(int index, bool moving) {
    // Clip each page before translating it. Card shadows deliberately overflow
    // their grid cells, but must never bleed into an adjacent desktop page.
    final framed = DesktopMotionScope(
        moving: moving && index == _toPage,
        child: ClipRect(
            key: ValueKey('desktop-motion-frame-$index'),
            child: widget.children[index]));
    // Transition widgets update their render layers directly. Do not rebuild
    // every Offstage/card tree from an AnimatedBuilder on every frame.
    // Keep BOTH wrappers mounted even at rest. Inserting/removing a wrapper
    // destroys the card subtree (including ActivityView and its virtual display).
    final active = moving && index == _toPage;
    return SlideTransition(
        position: active && widget.effect == 'slide'
            ? Tween<Offset>(
                    begin: Offset(_direction * .08, 0), end: Offset.zero)
                .animate(_curve)
            : const AlwaysStoppedAnimation(Offset.zero),
        child: FadeTransition(
            opacity: active && widget.effect == 'fade'
                ? Tween<double>(begin: .85, end: 1).animate(_curve)
                : const AlwaysStoppedAnimation(1),
            child: framed));
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
