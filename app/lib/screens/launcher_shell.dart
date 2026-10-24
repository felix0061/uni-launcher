import 'dart:async';
import 'package:flutter/material.dart';
import '../controller/launcher_controller.dart';
import '../theme/launcher_theme.dart';
import '../widgets/glass_surface.dart';
import '../widgets/editable_card.dart';
import '../widgets/bottom_dock.dart';
import 'settings_screen.dart';

class LauncherShell extends StatelessWidget {
  final LauncherController controller;
  const LauncherShell({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final s = SurfaceStyle.of(context);
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) controller.back();
        },
        child: Scaffold(
            body: DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: s.dark
                      ? [
                          Color.lerp(const Color(0xFF10202B), s.seed, .13)!,
                          const Color(0xFF263E48),
                          const Color(0xFF172D37)
                        ]
                      : [
                          Color.lerp(const Color(0xFFE7F0EA), s.seed, .10)!,
                          const Color(0xFFD6E3E5),
                          const Color(0xFFE9EFF0)
                        ])),
          child: SafeArea(
              top: false,
              child: LayoutBuilder(builder: (context, box) {
                final scale = box.maxWidth / 1600;
                return SizedBox.expand(
                    child: FittedBox(
                        fit: BoxFit.fill,
                        child: SizedBox(
                            width: 1600,
                            height: box.maxHeight / scale,
                            child: Column(children: [
                              Header(controller: controller),
                              Expanded(
                                  child: controller.settings
                                      ? SettingsScreen(controller: controller)
                                      : Desktop(controller: controller)),
                              Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 8, 24, 14),
                                  child: BottomDock(controller: controller)),
                            ]))));
              })),
        )));
  }
}

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
        height: 54,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Row(children: [
              Text(
                  '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 28),
              Text('UNI / LYNK & CO',
                  style: TextStyle(
                      color: s.muted, fontSize: 15, letterSpacing: 2)),
              const Spacer(),
              ValueListenableBuilder<Map<String, dynamic>>(
                  valueListenable: widget.controller.native,
                  builder: (context, native, _) => Text(
                      native['demo'] == true ? '模拟演示' : '原车接入 · 待核对',
                      style: TextStyle(color: s.muted, fontSize: 16))),
            ])));
  }
}

class Desktop extends StatelessWidget {
  final LauncherController controller;
  const Desktop({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: c.editing ? null : c.openSettings,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              if (c.editing)
                SizedBox(
                    height: 64,
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
              Expanded(child: LayoutBuilder(builder: (context, box) {
                const gap = 20.0;
                final unitX = (box.maxWidth + gap) / 12,
                    unitY = (box.maxHeight + gap) / 6,
                    items =
                        c.cards.where((card) => card.page == c.page).toList();
                return Stack(
                    key: const ValueKey('card-grid'),
                    clipBehavior: Clip.none,
                    children: [
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
              })),
              SizedBox(
                  height: 32,
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
                                      width: 38,
                                      height: 30,
                                      color: Colors.transparent,
                                      alignment: Alignment.center,
                                      child: Container(
                                          width: c.page == i ? 22 : 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                              color: SurfaceStyle.of(context)
                                                  .accent
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
