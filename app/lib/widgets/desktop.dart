import 'dart:async';
import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../theme/launcher_theme.dart';
import '../theme/design_tokens.dart';
import 'glass_surface.dart';
import 'editable_card.dart';
import 'uni_icon.dart';
import 'page_transition.dart';

class Header extends StatefulWidget {
  final LauncherController controller;
  const Header({super.key, required this.controller});
  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context), d = DateTime.now();
    return SizedBox(
        height: Design.px(64),
        child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Design.px(40)),
            child: Row(children: [
              Text(
                  '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                      fontSize: Design.px(23), fontWeight: FontWeight.w500)),
              const SizedBox(width: 28),
              Text('LYNK & CO / 05',
                  style: TextStyle(
                      color: s.muted, fontSize: 15, letterSpacing: 2)),
              const Spacer(),
              ValueListenableBuilder<Map<String, dynamic>>(
                  valueListenable: widget.controller.native,
                  builder: (context, native, _) => native['demo'] == true
                      ? Row(children: [
                          Text('演示',
                              style: TextStyle(
                                  color: s.muted, fontSize: Design.px(17))),
                          SizedBox(width: Design.px(24)),
                          UniIcon('cloud', size: Design.px(24), color: s.muted),
                          SizedBox(width: Design.px(10)),
                          Text('24° 多云',
                              style: TextStyle(
                                  color: s.muted, fontSize: Design.px(20))),
                          SizedBox(width: Design.px(40)),
                          UniIcon('bluetooth',
                              size: Design.px(28), color: s.muted),
                          SizedBox(width: Design.px(28)),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (int i = 0; i < 4; i++)
                                  Container(
                                      width: Design.px(4),
                                      height: Design.px(6 + i * 4),
                                      margin:
                                          EdgeInsets.only(right: Design.px(4)),
                                      color: s.muted)
                              ]),
                          SizedBox(width: Design.px(20)),
                          Text('4G',
                              style: TextStyle(
                                  color: s.muted, fontSize: Design.px(20)))
                        ])
                      : Text('原车接入 · 待核对',
                          style: TextStyle(
                              color: s.muted, fontSize: Design.px(19)))),
            ])));
  }
}

class Desktop extends StatelessWidget {
  final LauncherController controller;
  const Desktop({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final c = controller, visiblePage = controller.page;
    final visibleCards =
        c.cards.where((card) => card.page == visiblePage).toList();
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: c.editing ? null : c.openSettings,
        onHorizontalDragEnd: c.editing
            ? null
            : (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity.abs() > 180)
                  c.switchPage(c.page + (velocity < 0 ? 1 : -1));
              },
        child: Padding(
            padding: EdgeInsets.fromLTRB(
                Design.px(32), Design.px(16), Design.px(32), Design.px(24)),
            child: Column(children: [
              if (c.editing)
                SizedBox(
                    height: Design.px(74),
                    child: Row(children: [
                      const Text('编辑桌面', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 24),
                      Text('拖动标题移动 · 拖动角点缩放',
                          style: TextStyle(
                              color: SurfaceStyle.of(context).muted,
                              fontSize: 17)),
                      const Spacer(),
                      TextButton(
                          key: const ValueKey('cancel-edit'),
                          onPressed: c.cancelEdit,
                          child: const Text('取消')),
                      TextButton.icon(
                          key: const ValueKey('add-card'),
                          onPressed: () => showCardLibrary(context, c),
                          icon: const Icon(Icons.add),
                          label: const Text('添加卡片')),
                      FilledButton(
                          key: const ValueKey('finish-edit'),
                          onPressed: c.finishEdit,
                          child: const Text('完成'))
                    ])),
              Expanded(
                  child: DesktopPageTransition(
                      page: visiblePage,
                      effect: c.editing ? 'none' : c.appearance.pageTransition,
                      child: LayoutBuilder(builder: (context, box) {
                        const gap = 20.0;
                        final unitX = (box.maxWidth + gap) / 12,
                            unitY = (box.maxHeight + gap) / 6,
                            items = visibleCards;
                        return Stack(
                            key: const ValueKey('card-grid'),
                            clipBehavior: Clip.none,
                            children: [
                              if (c.editing)
                                Positioned.fill(
                                    child: IgnorePointer(
                                        child: CustomPaint(
                                            painter: _GridDots(
                                                unitX,
                                                unitY,
                                                SurfaceStyle.of(context)
                                                    .edge)))),
                              if (items.isEmpty)
                                Positioned.fill(
                                    child: Center(
                                        child: OutlinedButton.icon(
                                            onPressed: () {
                                              if (!c.editing) c.beginEdit();
                                              showCardLibrary(context, c);
                                            },
                                            icon: const Icon(Icons.add),
                                            label: const Text('添加一张卡片')))),
                              for (final card in items)
                                Positioned(
                                    key: ValueKey('position-${card.id}'),
                                    left: card.x * unitX,
                                    top: card.y * unitY,
                                    width: card.w * unitX - gap,
                                    height: card.h * unitY - gap,
                                    child: RepaintBoundary(
                                        child: EditableCard(
                                            key: ValueKey(card.id),
                                            card: card,
                                            controller: c,
                                            unitX: unitX,
                                            unitY: unitY))),
                            ]);
                      }))),
              SizedBox(height: Design.px(16)),
              SizedBox(
                  height: Design.px(16),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < c.pageCount; i++)
                          Semantics(
                              label: '桌面第${i + 1}页',
                              button: true,
                              child: GestureDetector(
                                  key: ValueKey('page-$i'),
                                  onTap: () => c.switchPage(i),
                                  child: Container(
                                      width: Design.px(38),
                                      height: Design.px(16),
                                      color: Colors.transparent,
                                      alignment: Alignment.center,
                                      child: Container(
                                          width: c.page == i
                                              ? Design.px(24)
                                              : Design.px(8),
                                          height: Design.px(8),
                                          decoration: BoxDecoration(
                                              color: (c.page == i
                                                      ? SurfaceStyle.of(context)
                                                          .accent
                                                      : SurfaceStyle.of(context)
                                                          .muted)
                                                  .withValues(
                                                      alpha:
                                                          c.page == i ? 1 : .3),
                                              borderRadius:
                                                  BorderRadius.circular(4)))))),
                        if (c.editing)
                          IconAction(
                              icon: Icons.add,
                              label: '新建桌面页',
                              size: 32,
                              onTap: c.newPage)
                      ])),
            ])));
  }
}

class _GridDots extends CustomPainter {
  final double unitX, unitY;
  final Color color;
  _GridDots(this.unitX, this.unitY, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (double x = 0; x < size.width; x += unitX)
      for (double y = 0; y < size.height; y += unitY)
        canvas.drawCircle(Offset(x, y), Design.px(1.5), p);
  }

  @override
  bool shouldRepaint(_GridDots old) =>
      old.unitX != unitX || old.unitY != unitY || old.color != color;
}
