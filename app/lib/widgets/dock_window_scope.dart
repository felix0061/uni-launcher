import 'package:flutter/widgets.dart';

/// Identifies the independently positioned panel window and its first frame.
class DockWindowScope extends InheritedWidget {
  final Future<void> Function(bool) expand;
  final Future<void> Function()? onPresented;
  const DockWindowScope(
      {super.key,
      required this.expand,
      this.onPresented,
      required super.child});
  static DockWindowScope? of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<DockWindowScope>();
  @override
  bool updateShouldNotify(DockWindowScope oldWidget) => false;
}
