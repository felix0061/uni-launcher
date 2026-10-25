import 'package:flutter/widgets.dart';

/// Supplies the same panels with a full overlay window only while they are open.
class DockWindowScope extends InheritedWidget {
  final Future<void> Function(bool) expand;
  const DockWindowScope(
      {super.key, required this.expand, required super.child});
  static DockWindowScope? of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<DockWindowScope>();
  @override
  bool updateShouldNotify(DockWindowScope oldWidget) => false;
}
