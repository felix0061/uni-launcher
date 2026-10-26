import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_launcher/widgets/native_slice_builder.dart';

void main() {
  testWidgets('unrelated vehicle samples do not rebuild a weather card',
      (t) async {
    final state = ValueNotifier<Map<String, dynamic>>({
      'weather': {
        'city': '上海市',
        'days': [23, 24]
      },
      'vehicle': {'speed': 0}
    });
    var builds = 0;
    await t.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: NativeSliceBuilder(
            valueListenable: state,
            select: (s) => s['weather'],
            builder: (_, s) {
              builds++;
              return Text('${(s['weather'] as Map)['city']}');
            })));
    for (var i = 0; i < 60; i++) {
      state.value = {
        'weather': {
          'city': '上海市',
          'days': [23, 24]
        },
        'vehicle': {'speed': i}
      };
      await t.pump();
    }
    expect(builds, 1);
    state.value = {
      'weather': {
        'city': '杭州市',
        'days': [23, 24]
      }
    };
    await t.pump();
    expect(builds, 2);
    expect(find.text('杭州市'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    state.dispose();
  });

  testWidgets('hidden card applies latest state when page becomes visible',
      (t) async {
    final state = ValueNotifier<Map<String, dynamic>>({'value': 1});
    var builds = 0;
    final card = NativeSliceBuilder(
        valueListenable: state,
        select: (s) => s['value'],
        builder: (_, s) {
          builds++;
          return Text('${s['value']}');
        });
    Widget page(bool enabled) => Directionality(
        textDirection: TextDirection.ltr,
        child: TickerMode(enabled: enabled, child: card));
    await t.pumpWidget(page(false));
    state.value = {'value': 2};
    await t.pump();
    expect(builds, 1);
    await t.pumpWidget(page(true));
    expect(builds, 2);
    expect(find.text('2'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    state.dispose();
  });
}
