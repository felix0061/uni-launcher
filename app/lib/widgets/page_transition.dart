import 'package:flutter/material.dart';

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
        vsync: this, duration: const Duration(milliseconds: 220));
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
            Duration(milliseconds: widget.effect == 'fade' ? 180 : 220);
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
    return ClipRect(
        child: AnimatedBuilder(
            animation: _curve,
            builder: (context, _) {
              final moving = !_motionDisabled && _fromPage != _toPage;
              final value = moving ? _curve.value : 1.0;
              return Stack(fit: StackFit.expand, children: [
                for (var i = 0; i < widget.children.length; i++)
                  Positioned.fill(
                      key: ValueKey('desktop-motion-page-$i'),
                      child: Offstage(
                          offstage: moving
                              ? i != _fromPage && i != _toPage
                              : i != _toPage,
                          child: IgnorePointer(
                              ignoring: i != _toPage,
                              child: ExcludeSemantics(
                                  excluding: i != _toPage,
                                  child: TickerMode(
                                      enabled: i == _toPage,
                                      child: RepaintBoundary(
                                          child: _animatedPage(
                                              i, moving, value))))))),
              ]);
            }));
  }

  Widget _animatedPage(int index, bool moving, double value) {
    // Clip each page before translating it. Card shadows deliberately overflow
    // their grid cells, but must never bleed into an adjacent desktop page.
    final framed = ClipRect(
        key: ValueKey('desktop-motion-frame-$index'),
        child: widget.children[index]);
    if (!moving) return framed;
    if (widget.effect == 'fade') {
      return Opacity(
          opacity: index == _toPage ? value : 1 - value, child: framed);
    }
    final offset =
        index == _toPage ? _direction * (1 - value) : -_direction * value;
    return FractionalTranslation(
        translation: Offset(offset.toDouble(), 0), child: framed);
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
