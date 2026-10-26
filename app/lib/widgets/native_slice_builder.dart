import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A card only rebuilds for its own inputs, and waits until it is visible before
/// applying background updates. Incoming state is never dropped or mutated.
class NativeSliceBuilder extends StatefulWidget {
  final ValueListenable<Map<String, dynamic>> valueListenable;
  final Object? Function(Map<String, dynamic>) select;
  final Widget Function(BuildContext, Map<String, dynamic>) builder;
  const NativeSliceBuilder(
      {super.key,
      required this.valueListenable,
      required this.select,
      required this.builder});

  @override
  State<NativeSliceBuilder> createState() => _NativeSliceBuilderState();
}

class _NativeSliceBuilderState extends State<NativeSliceBuilder> {
  Object? _selection;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    widget.valueListenable.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled = TickerMode.valuesOf(context).enabled;
  }

  @override
  void didUpdateWidget(NativeSliceBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valueListenable != widget.valueListenable) {
      oldWidget.valueListenable.removeListener(_changed);
      widget.valueListenable.addListener(_changed);
    }
  }

  void _changed() {
    if (!_enabled) return;
    final next = widget.select(widget.valueListenable.value);
    if (!_same(_selection, next)) setState(() => _selection = next);
  }

  static bool _same(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_same(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_same(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.valueListenable.value;
    _selection = widget.select(value);
    return widget.builder(context, value);
  }

  @override
  void dispose() {
    widget.valueListenable.removeListener(_changed);
    super.dispose();
  }
}
