import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

DayStat _day(DateTime d, int orders) =>
    DayStat.fromJson({'date': d.toIso8601String().substring(0, 10), 'orders': orders, 'valueMinor': orders * 10000});

void main() {
  testWidgets('rating badge shows the average and count, or says there are none', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Column(children: [
      RatingBadge(rating: 4.5, count: 120),
      RatingBadge(rating: null, count: 0),
    ])));
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text(' (120)'), findsOneWidget);
    expect(find.text('No ratings yet'), findsOneWidget);
  });

  testWidgets('star picker reports the star tapped', (tester) async {
    var chosen = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StarPicker(value: 0, onChanged: (v) => chosen = v))));
    await tester.tap(find.byTooltip('4 stars: Good'));
    expect(chosen, 4);
  });

  testWidgets('daily bars label each day for a week and only the ends for a month', (tester) async {
    final start = DateTime(2026, 10, 8);
    final week = [for (var i = 0; i < 7; i++) _day(start.add(Duration(days: i)), i)];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DailyBars(title: 'Orders', days: week))));
    expect(find.text('21 orders'), findsOneWidget);
    expect(find.text('Thu'), findsOneWidget);
    expect(find.byTooltip('Wed 14 Oct\n6 orders · ₹600'), findsOneWidget);

    final month = [for (var i = 0; i < 30; i++) _day(DateTime(2026, 9, 15).add(Duration(days: i)), 1)];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DailyBars(title: 'Orders', days: month))));
    expect(find.text('15 Sep'), findsOneWidget);
    expect(find.text('14 Oct'), findsOneWidget);
    expect(find.text('Thu'), findsNothing);
  });
}
