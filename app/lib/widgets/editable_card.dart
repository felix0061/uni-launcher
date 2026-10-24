import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../model/card_layout.dart';
import '../theme/launcher_theme.dart';
import 'card_content.dart';
import 'glass_surface.dart';

class EditableCard extends StatefulWidget {
  final LauncherCard card;
  final LauncherController controller;
  final double unitX, unitY;
  const EditableCard(
      {super.key,
      required this.card,
      required this.controller,
      required this.unitX,
      required this.unitY});
  @override
  State<EditableCard> createState() => _EditableCardState();
}

class _EditableCardState extends State<EditableCard> {
  LauncherCard? origin;
  Offset delta = Offset.zero;
  void start(DragStartDetails details) {
    origin = widget.card;
    delta = Offset.zero;
  }

  void move(DragUpdateDetails details, bool resize) {
    if (origin == null) return;
    delta += details.delta;
    final card = origin!,
        spec = specFor(card.type),
        dx = (delta.dx / widget.unitX).round(),
        dy = (delta.dy / widget.unitY).round();
    widget.controller.transform(resize
        ? card.copyWith(
            w: (card.w + dx).clamp(spec.minW, 12 - card.x),
            h: (card.h + dy).clamp(spec.minH, 6 - card.y))
        : card.copyWith(
            x: (card.x + dx).clamp(0, 12 - card.w),
            y: (card.y + dy).clamp(0, 6 - card.h)));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller,
        s = SurfaceStyle.of(context),
        card = widget.card;
    return GestureDetector(
        onLongPress: c.editing ? null : c.beginEdit,
        child: GlassSurface(
            padding: EdgeInsets.zero,
            child: Stack(children: [
              Positioned.fill(
                  top: c.editing ? 50 : 0,
                  child: CardContent(card: card, controller: c)),
              if (c.editing) ...[
                Positioned(
                    top: 3,
                    left: 10,
                    right: 4,
                    height: 44,
                    child: Row(children: [
                      Expanded(
                          child: GestureDetector(
                              key: ValueKey('move-${card.id}'),
                              behavior: HitTestBehavior.opaque,
                              onPanStart: start,
                              onPanUpdate: (d) => move(d, false),
                              onPanEnd: (_) => origin = null,
                              child: Row(children: [
                                Icon(Icons.drag_indicator,
                                    color: s.accent, size: 22),
                                const SizedBox(width: 4),
                                Flexible(
                                    child: Text(card.title,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 17, color: s.accent))),
                                const SizedBox(width: 10),
                                Text('${card.w} × ${card.h}',
                                    style:
                                        TextStyle(color: s.muted, fontSize: 13))
                              ]))),
                      IconAction(
                          icon: Icons.edit_outlined,
                          label: '编辑${card.title}',
                          size: 36,
                          onTap: () => editCard(context, c, card)),
                      IconAction(
                          key: ValueKey('delete-${card.id}'),
                          icon: Icons.close,
                          label: '删除${card.title}',
                          size: 36,
                          onTap: () {
                            c.remove(card.id);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: const Text('卡片已移除'),
                                action: SnackBarAction(
                                    label: '撤销', onPressed: c.undoRemove)));
                          })
                    ])),
                Positioned(
                    bottom: 0,
                    right: 0,
                    width: 42,
                    height: 42,
                    child: GestureDetector(
                        key: ValueKey('resize-${card.id}'),
                        onPanStart: start,
                        onPanUpdate: (d) => move(d, true),
                        onPanEnd: (_) => origin = null,
                        child: Container(
                            decoration: BoxDecoration(
                                color: s.accent,
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(s.radius * .65))),
                            child: Icon(Icons.open_in_full,
                                size: 22,
                                color: s.dark
                                    ? const Color(0xFF183039)
                                    : Colors.white)))),
              ]
            ])));
  }
}

Future<void> showCardLibrary(BuildContext context, LauncherController c) =>
    showDialog(
        context: context,
        builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: SizedBox(
                width: 1100,
                height: 680,
                child: GlassSurface(
                    child: Column(children: [
                  Row(children: [
                    const Text('添加卡片', style: TextStyle(fontSize: 30)),
                    const Spacer(),
                    IconAction(
                        icon: Icons.close,
                        label: '关闭卡片库',
                        onTap: () => Navigator.pop(context))
                  ]),
                  const SizedBox(height: 20),
                  Expanded(
                      child: GridView.builder(
                          itemCount: librarySpecs.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 2),
                          itemBuilder: (context, i) {
                            final spec = librarySpecs[i];
                            return OutlinedButton(
                                key: ValueKey('add-${spec.type}'),
                                onPressed: () {
                                  if (c.add(spec.type)) Navigator.pop(context);
                                },
                                child: Row(children: [
                                  Icon(cardIcon(spec.type), size: 36),
                                  const SizedBox(width: 20),
                                  Expanded(
                                      child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(spec.label,
                                            style:
                                                const TextStyle(fontSize: 22)),
                                        const SizedBox(height: 8),
                                        Text(spec.source,
                                            style:
                                                const TextStyle(fontSize: 14))
                                      ])),
                                  const Icon(Icons.add)
                                ]));
                          }))
                ])))));

Future<void> editCard(
    BuildContext context, LauncherController c, LauncherCard card) async {
  final input = TextEditingController(text: card.title);
  await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
              title: const Text('编辑卡片'),
              content: SizedBox(
                  width: 440,
                  child: TextField(
                      key: const ValueKey('card-title'),
                      controller: input,
                      maxLength: 20,
                      decoration: const InputDecoration(labelText: '卡片名称'))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: () {
                      c.transform(card.copyWith(
                          title: input.text.trim().isEmpty
                              ? specFor(card.type).label
                              : input.text.trim()));
                      Navigator.pop(context);
                    },
                    child: const Text('保存'))
              ]));
  input.dispose();
}
