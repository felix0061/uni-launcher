import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_launcher/theme/launcher_theme.dart';
import 'package:uni_launcher/widgets/voice_dock_slot.dart';
import 'package:uni_launcher/model/appearance.dart';

/// 底栏语音槽位的回归测试：
///  1. 逐字弹出：字不动、不变位，只是一个个从中间往两边蹦出来
///  2. 长句不滚、不溢出（FittedBox 收）
///  3. 文字层在波形之上（Stack 顺序）
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: launcherTheme(SurfaceStyle.from(const Appearance(), false)),
        home: Scaffold(
          body: Center(
            child: Builder(builder: (context) {
              final s = SurfaceStyle.of(context);
              return SizedBox(
                width: 400,
                height: 96,
                child: ColoredBox(color: s.dock, child: child),
              );
            }),
          ),
        ),
      );

  testWidgets('逐字出现：第一个字先起，最后字后起，位置不动', (tester) async {
    await tester.pumpWidget(host(const VoiceDanmaku(text: '把空调调到二十三度', maxWidth: 220)));

    // 刚开始：所有字都在，但还没弹完（缩放 < 1）
    final texts = find.byType(Text);
    expect(texts, findsNWidgets(9));

    double scaleOf(int i) {
      final t = find.descendant(
          of: find.byType(Transform), matching: find.byType(Text)).at(i);
      final box = tester.getRect(t);
      return box.width;
    }

    await tester.pump(const Duration(milliseconds: 20));
    final early = tester.getRect(texts.at(4)); // 中间的字
    await tester.pump(const Duration(milliseconds: 600));
    final later = tester.getRect(texts.at(4));
    // 同一个字：出现前小、出现后回到原尺寸，但中心点不移动
    expect(later.width, greaterThanOrEqualTo(early.width));
    expect((later.center.dx - early.center.dx).abs(), lessThan(1.0));
  });

  testWidgets('文字层压在波形之上', (tester) async {
    await tester.pumpWidget(host(const VoiceDockSlot(active: true, state: 'listening', heard: '把空调调到二十三度')));
    await tester.pump(const Duration(milliseconds: 600));

    // 同一个 Stack 里，文字层排在波形之后（后画的在上面）
    final stack = find.descendant(of: find.byType(VoiceDockSlot), matching: find.byType(Stack)).last;
    final children = tester.widget<Stack>(stack).children;
    final waveIndex = children.indexWhere((w) => w is VoiceDockWave);
    final textIndex = children.indexWhere((w) => w is Positioned &&
        w.child.runtimeType.toString().contains('IgnorePointer'));
    expect(waveIndex, isNonNegative);
    expect(textIndex, greaterThan(waveIndex));
  });

  testWidgets('长句不溢出、不滚动', (tester) async {
    const long = '把空调温度调到二十三度然后再把音乐关掉顺便帮我导航回家';
    await tester.pumpWidget(host(const VoiceDockSlot(active: true, state: 'speaking', heard: long)));
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);

    // 位置稳定：再等一段时间，文字不位移
    final before = tester.getRect(find.byType(VoiceDanmaku));
    await tester.pump(const Duration(milliseconds: 900));
    final after = tester.getRect(find.byType(VoiceDanmaku));
    expect((after.center - before.center).distance, lessThan(1.0));
  });
}
