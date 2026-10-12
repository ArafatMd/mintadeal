import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mintadeal_core/mintadeal_core.dart';
import 'package:mintadeal_customer/src/cart.dart';
import 'package:mintadeal_customer/src/cart_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

DiscoveryItem _item(String id, {bool offer = false}) => DiscoveryItem.fromJson({
      'listing': {
        'id': id,
        'vendorId': 'v1',
        'listingType': offer ? 'OFFER' : 'PRODUCT',
        'title': 'Item $id',
        'category': 'GROCERY',
        'priceMinor': 10000,
        'status': 'ACTIVE',
        'fulfilmentModes': [offer ? 'VENUE_QR' : 'PICKUP'],
        'createdAt': '2026-10-12T10:00:00Z',
        'updatedAt': '2026-10-12T10:00:00Z',
      },
      'vendor': {'id': 'v1', 'displayName': 'Lakshmi Stores', 'category': 'GROCERY', 'area': 'HSR Layout'},
      'deliverable': false,
      'pickupAvailable': true,
      'venueOffer': offer,
      'followed': false,
    });

void main() {
  test('cart merges repeated items and caps quantity', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cart = container.read(cartProvider.notifier);
    cart.add(_item('a'));
    cart.add(_item('a'));
    cart.add(_item('b'));
    expect(container.read(cartCountProvider), 3);
    cart.setQuantity('a', 99);
    expect(cart.quantityOf('a'), CartController.maxQuantity);
    cart.setQuantity('b', 0);
    expect(container.read(cartProvider).map((e) => e.listingId), ['a']);
  });

  testWidgets('cart shows the server quote and only allows online payment for venue offers', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final bodies = <Map<String, dynamic>>[];
    final client = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      bodies.add(body);
      return http.Response(
        jsonEncode({
          'groups': [
            {
              'key': 'v1:OFFER',
              'vendor': {'id': 'v1', 'name': 'Glow Salon', 'area': 'HSR Layout'},
              'kind': 'OFFER',
              'lines': [
                {
                  'listingId': 'o1', 'listingType': 'OFFER', 'title': 'Haircut', 'unitPriceMinor': 49900,
                  'originalPriceMinor': 80000, 'quantity': 1, 'lineTotalMinor': 49900,
                }
              ],
              'availableModes': ['VENUE_QR'],
              'selectedMode': 'VENUE_QR',
              'itemsTotalMinor': 49900,
              'deliveryFeeMinor': 0,
              'totalMinor': 49900,
              'minOrderMinor': 0,
              'problems': [],
            }
          ],
          'itemsTotalMinor': 49900,
          'deliveryTotalMinor': 0,
          'grandTotalMinor': 49900,
          'onlinePaymentAvailable': true,
          'payOnDeliveryAllowed': false,
          'addressRequired': false,
          'problems': [],
          'canPlace': true,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final container = ProviderContainer(overrides: [
      apiProvider.overrideWithValue(MintadealApi(ApiClient(baseUrl: 'http://t', token: () => null, httpClient: client))),
    ]);
    addTearDown(container.dispose);
    container.read(cartProvider.notifier).add(_item('o1', offer: true));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: mintadealTheme(), home: const CartScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Glow Salon'), findsOneWidget);
    expect(find.text('Venue offers are paid online'), findsOneWidget);
    expect(find.text('Pay ₹499'), findsOneWidget);
    // After the first quote the cart switches to online payment, the only method allowed.
    expect(bodies.last['paymentMethod'], 'ONLINE');
    expect(bodies.last['items'], [
      {'listingId': 'o1', 'quantity': 1}
    ]);
  });
}
