import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../theme/design_tokens.dart';

/// An explicit OEM entry; it does not claim to supply the unified card's fields.
class OfficialCardEntry extends StatelessWidget {
  final String type, label;
  final LauncherController controller;
  final Widget child;
  const OfficialCardEntry(
      {super.key,
      required this.type,
      required this.label,
      required this.controller,
      required this.child});

  @override
  Widget build(BuildContext context) {
    if (controller.editing) return child;
    return Column(children: [
      Expanded(child: child),
      Padding(
          padding: EdgeInsets.fromLTRB(
              Design.px(20), 0, Design.px(20), Design.px(12)),
          child: SizedBox(
              width: double.infinity,
              height: Design.px(44),
              child: OutlinedButton(
                  key: ValueKey('official-entry-$type'),
                  style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: Design.px(8)),
                      minimumSize: Size.zero,
                      textStyle: TextStyle(fontSize: Design.px(18))),
                  onPressed: () =>
                      controller.command('official-widget', value: type),
                  child: Text('打开原车$label',
                      maxLines: 1, overflow: TextOverflow.ellipsis)))),
    ]);
  }
}
