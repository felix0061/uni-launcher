import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../model/card_layout.dart';
import '../theme/launcher_theme.dart';
import '../theme/design_tokens.dart';
import 'card_content.dart';
import 'glass_surface.dart';
import 'launcher_dialog.dart';
import 'uni_icon.dart';

part 'card_editor_sheet.dart';

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
  bool rejectionShown = false;
  void start(DragStartDetails details) {
    origin = widget.card;
    delta = Offset.zero;
    rejectionShown = false;
  }

  void move(DragUpdateDetails details, bool resize) {
    if (origin == null) return;
    delta += details.delta;
    final card = origin!,
        spec = specFor(card.type),
        dx = (delta.dx / widget.unitX).round(),
        dy = (delta.dy / widget.unitY).round();
    final accepted = widget.controller.transform(resize
        ? card.copyWith(
            w: (card.w + dx).clamp(spec.minW, 12 - card.x),
            h: (card.h + dy).clamp(spec.minH, 6 - card.y))
        : card.copyWith(
            x: (card.x + dx).clamp(0, 12 - card.w),
            y: (card.y + dy).clamp(0, 6 - card.h)));
    if (!accepted && !rejectionShown) {
      rejectionShown = true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(resize ? '此处空间不足，请先移动其他卡片再调整尺寸' : '此处已有卡片，请移动到空白位置')));
    }
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
            borderColor: c.editing ? s.accent : null,
            child: Stack(children: [
              Positioned.fill(
                  top: c.editing ? Design.px(64) : 0,
                  child: CardContent(card: card, controller: c)),
              if (c.editing) ...[
                Positioned(
                    top: Design.px(8),
                    left: Design.px(14),
                    right: Design.px(12),
                    height: Design.px(46),
                    child: Row(children: [
                      Expanded(
                          child: GestureDetector(
                              key: ValueKey('move-${card.id}'),
                              behavior: HitTestBehavior.opaque,
                              onPanStart: start,
                              onPanUpdate: (d) => move(d, false),
                              onPanEnd: (_) => origin = null,
                              onPanCancel: () => origin = null,
                              child: Row(children: [
                                UniIcon('move',
                                    color: s.accent, size: Design.px(23)),
                                SizedBox(width: Design.px(9)),
                                Flexible(
                                    child: Text(card.title,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: Design.px(21),
                                            color: s.accent))),
                                SizedBox(width: Design.px(9)),
                                Text('${card.w} × ${card.h}',
                                    style: TextStyle(
                                        color: s.muted,
                                        fontSize: Design.px(15)))
                              ]))),
                      IconAction(
                          icon: Icons.edit_outlined,
                          label: '编辑${card.title}',
                          size: Design.px(44),
                          iconSize: Design.px(22),
                          soft: true,
                          onTap: () => editCard(context, c, card)),
                      SizedBox(width: Design.px(9)),
                      _DeleteCardAction(card: card, controller: c),
                    ])),
                Positioned(
                    bottom: 0,
                    right: 0,
                    width: Design.px(48),
                    height: Design.px(48),
                    child: GestureDetector(
                        key: ValueKey('resize-${card.id}'),
                        onPanStart: start,
                        onPanUpdate: (d) => move(d, true),
                        onPanEnd: (_) => origin = null,
                        onPanCancel: () => origin = null,
                        child: Container(
                            decoration: BoxDecoration(
                                color: s.accent,
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(s.controlRadius))),
                            child: Center(
                                child: UniIcon('resize',
                                    size: Design.px(24),
                                    color: s.accentText))))),
              ]
            ])));
  }
}

class _DeleteCardAction extends StatelessWidget {
  final LauncherCard card;
  final LauncherController controller;
  const _DeleteCardAction({required this.card, required this.controller});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return Tooltip(
        message: '删除${card.title}',
        child: Semantics(
            button: true,
            label: '删除${card.title}',
            child: SizedBox(
                width: Design.px(44),
                height: Design.px(44),
                child: Material(
                    color: s.soft,
                    borderRadius: BorderRadius.circular(s.controlRadius),
                    child: InkWell(
                        key: ValueKey('delete-${card.id}'),
                        borderRadius: BorderRadius.circular(s.controlRadius),
                        onTap: () {
                          controller.remove(card.id);
                          showLauncherToast(context, '卡片已移除');
                        },
                        child: Center(
                            child: UniIcon('trash',
                                size: Design.px(22), color: s.text)))))));
  }
}
