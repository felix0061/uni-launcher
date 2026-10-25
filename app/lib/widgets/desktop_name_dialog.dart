import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../model/appearance.dart';
import '../theme/design_tokens.dart';
import 'launcher_dialog.dart';

Future<void> showDesktopNameDialog(
    BuildContext context, LauncherController c) async {
  final name = await showLauncherSheet<String>(context,
      title: '桌面名称',
      closeLabel: '关闭名称编辑',
      width: Design.px(680),
      height: Design.px(380),
      builder: (_) => _DesktopNameEditor(initial: c.appearance.desktopName));
  if (name != null) c.setAppearance(c.appearance.copyWith(desktopName: name));
}

class _DesktopNameEditor extends StatefulWidget {
  final String initial;
  const _DesktopNameEditor({required this.initial});
  @override
  State<_DesktopNameEditor> createState() => _DesktopNameEditorState();
}

class _DesktopNameEditorState extends State<_DesktopNameEditor> {
  late final input = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            TextField(
                key: const ValueKey('desktop-name-input'),
                controller: input,
                maxLength: 24,
                maxLines: 1,
                decoration: const InputDecoration(labelText: '自定义名称'),
                onSubmitted: (v) => Navigator.pop(context, v)),
            SizedBox(height: Design.px(24)),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                  onPressed: () =>
                      Navigator.pop(context, Appearance.defaultDesktopName),
                  child: const Text('恢复默认')),
              SizedBox(width: Design.px(16)),
              FilledButton(
                  key: const ValueKey('desktop-name-save'),
                  onPressed: () => Navigator.pop(context, input.text),
                  child: const Text('保存')),
            ]),
          ]));
}
