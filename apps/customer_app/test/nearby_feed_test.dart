import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mintadeal_core/mintadeal_core.dart';
import 'package:mintadeal_customer/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _item(String title, {bool venue = false}) => {
      'listing': {
        'id': title,
        'vendorId': 'v1',
        'listingType': venue ? 'OFFER' : 'PRODUCT',
        'title': title,
        'category': 'GROCERY',
        'priceMinor': 29500,
        'offerPriceMinor': 26900,
        'discountPercent': 9,
        'status': 'ACTIVE',
        'fulfilmentModes': [venue ? 'VENUE_QR' : 'PICKUP'],
        'createdAt': '2026-10-12T10:00:00Z',
        'updatedAt': '2026-10-12T10:00:00Z',
      },
      'vendor': {'id': 'v1', 'displayName': 'Sri Lakshmi Provisions', 'category': 'GROCERY', 'area': 'HSR Layout'},
      'distanceKm': 0.3,
      'deliverable': false,
      'pickupAvailable': !venue,
      'venueOffer': venue,
      'deliveryFeeMinor': null,
      'followed': false,
    };

void main() {
  testWidgets('Nearby shows deals from the API with price and availability', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final requests = <Uri>[];
    final client = MockClient((req) async {
      requests.add(req.url);
      return http.Response(
          jsonEncode({'items': [_item('Aashirvaad Atta 5 kg')], 'page': 0, 'size': 20, 'total': 1}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(
            MintadealApi(ApiClient(baseUrl: 'http://test', token: () => null, httpClient: client))),
      ],
      child: const CustomerApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Nearby deals'), findsOneWidget);
    expect(find.text('Aashirvaad Atta 5 kg'), findsOneWidget);
    expect(find.text('₹269'), findsOneWidget);
    expect(find.text('9% off'), findsOneWidget);
    expect(find.text('Pickup'), findsOneWidget);
    expect(requests.first.path, '/api/discovery/nearby');
    expect(requests.first.queryParameters['lat'], '12.9116');
  });

  testWidgets('Following asks a signed-out customer to sign in', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final client = MockClient((_) async => http.Response('{"items":[],"page":0,"size":20,"total":0}', 200));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(
            MintadealApi(ApiClient(baseUrl: 'http://test', token: () => null, httpClient: client))),
      ],
      child: const CustomerApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(find.text('Follow the shops you like'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });
}
