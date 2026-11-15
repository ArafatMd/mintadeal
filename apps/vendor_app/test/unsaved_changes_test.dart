import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mintadeal_core/mintadeal_core.dart';
import 'package:mintadeal_vendor/src/listing_form_screen.dart';

final _shop = Vendor({
  'id': 'v1', 'displayName': 'Corner Bakery', 'category': 'BAKERY', 'vendorType': 'EXTERNAL', 'status': 'APPROVED',
  'phone': '+919000000101', 'area': 'HSR Layout', 'addressLine': '1 Main Road', 'createdAt': '2026-11-01T00:00:00Z',
  'selfDelivery': true, 'partnerDelivery': false, 'pickup': true, 'citywideDelivery': false, 'deliveryRadiusKm': 3,
});

Future<void> _openForm(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: mintadealTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => ListingFormScreen(shop: _shop, existing: null))),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('leaving a product with changes asks first; discarding leaves', (tester) async {
    await _openForm(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Butter cookies');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('You have unsaved changes'), findsOneWidget);
    expect(find.text('Save draft'), findsWidgets);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('New listing'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('leaving an untouched product just closes it', (tester) async {
    await _openForm(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('You have unsaved changes'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });
}
