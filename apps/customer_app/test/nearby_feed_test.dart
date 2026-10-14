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

Map<String, dynamic> _shop() => {
      'vendor': {'id': 'v1', 'displayName': 'Sri Lakshmi Provisions', 'category': 'GROCERY', 'area': 'HSR Layout'},
      'tagline': 'Groceries and daily needs',
      'distanceKm': 0.3,
      'followed': false,
      'followers': 12,
      'dealCount': 2,
      'bestDiscountPercent': 25,
      'coverImageUrl': null,
      'tag': 'NEW',
    };

/// Answers shop and deal requests like the API; records every request.
MockClient _api(List<Uri> requests, {List<Map<String, dynamic>> banners = const []}) => MockClient((req) async {
      requests.add(req.url);
      final Object body = req.url.path.endsWith('/banners')
          ? banners
          : req.url.path.endsWith('/shops')
              ? {'items': [_shop()], 'page': 0, 'size': 20, 'total': 1}
              : {'items': [_item('Aashirvaad Atta 5 kg')], 'page': 0, 'size': 20, 'total': 1};
      return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });

Future<void> _pumpApp(WidgetTester tester, MockClient client, {Map<String, Object> prefs = const {}}) async {
  // A phone screen.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'mintadeal.locationPromptDismissed': true, ...prefs});
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiProvider.overrideWithValue(
          MintadealApi(ApiClient(baseUrl: 'http://test', token: () => null, httpClient: client))),
    ],
    child: const CustomerApp(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Home offers to use the location until it is used or dismissed', (tester) async {
    await _pumpApp(tester, _api([]), prefs: {'mintadeal.locationPromptDismissed': false});
    expect(find.text('See how far shops are from you'), findsOneWidget);
    await tester.tap(find.byTooltip('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('See how far shops are from you'), findsNothing);
  });

  testWidgets('A saved location is named after the nearest area and searched from', (tester) async {
    final requests = <Uri>[];
    await _pumpApp(tester, _api(requests), prefs: {
      'mintadeal.area': '{"name":"HSR Layout","lat":12.9141,"lng":77.6389,"precise":true}',
    });
    expect(find.text('Near HSR Layout'), findsOneWidget);
    final shops = requests.lastWhere((u) => u.path == '/api/discovery/nearby/shops');
    expect(shops.queryParameters['lat'], '12.9141');
  });

  testWidgets('An area saved by an older version is still restored', (tester) async {
    await _pumpApp(tester, _api([]), prefs: {'mintadeal.area': 'Indiranagar'});
    expect(find.text('Indiranagar'), findsOneWidget);
  });

  testWidgets('Home shows nearby shops with their best deal and a banner from it', (tester) async {
    final requests = <Uri>[];
    await _pumpApp(tester, _api(requests));

    expect(find.text('NEARBY DEALS'), findsOneWidget);
    expect(find.text('Sri Lakshmi Provisions'), findsOneWidget);
    expect(find.text('Groceries and daily needs'), findsOneWidget);
    expect(find.text('25% OFF'), findsOneWidget);
    expect(find.text('New deals'), findsOneWidget);
    expect(find.text('Up to 25% Off'), findsOneWidget);
    expect(find.text('On Grocery'), findsOneWidget);
    final shops = requests.firstWhere((u) => u.path == '/api/discovery/nearby/shops');
    expect(shops.queryParameters['lat'], '12.9116');
    expect(requests.any((u) => u.path == '/api/discovery/banners' && u.queryParameters['scope'] == 'NEARBY'), isTrue);
  });

  testWidgets('See all lists every deal, and ADD fills the cart', (tester) async {
    final requests = <Uri>[];
    await _pumpApp(tester, _api(requests));
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(requests.last.path, '/api/discovery/nearby');
    expect(find.text('Aashirvaad Atta 5 kg'), findsOneWidget);
    expect(find.text('₹269'), findsOneWidget);
    expect(find.text('9%\nOFF'), findsOneWidget);
    expect(find.text('Pickup'), findsOneWidget);

    // ADD turns into a quantity stepper and the cart bar appears with the total and savings.
    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();
    expect(find.text('ADD'), findsNothing);
    expect(find.byTooltip('Remove'), findsOneWidget);
    expect(find.text('1 item · ₹269'), findsOneWidget);
    expect(find.text('You save ₹26'), findsOneWidget);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('2 items · ₹538'), findsOneWidget);
  });

  testWidgets('Products shows the products themselves instead of shops', (tester) async {
    final requests = <Uri>[];
    await _pumpApp(tester, _api(requests));
    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();
    final deals = requests.lastWhere((u) => u.path == '/api/discovery/nearby');
    expect(deals.queryParameters['type'], 'PRODUCT');
    expect(find.text('Products near HSR Layout'), findsOneWidget);
    expect(find.text('Aashirvaad Atta 5 kg'), findsOneWidget);
    expect(find.text('See all'), findsNothing);
  });

  testWidgets('Admin banners replace the generated ones', (tester) async {
    await _pumpApp(
        tester,
        _api([], banners: [
          {
            'id': 'b1',
            'title': 'Diwali Mega Sale',
            'subtitle': 'Sweets and gifts',
            'kicker': 'Festive offers',
            'imageUrl': 'http://test/files/banner.jpg',
            'targetType': 'CATEGORY',
            'targetCategory': 'BAKERY',
          },
        ]));
    expect(find.text('Diwali Mega Sale'), findsOneWidget);
    expect(find.text('FESTIVE OFFERS'), findsOneWidget);
    expect(find.text('Up to 25% Off'), findsNothing);
    await tester.tap(find.text('View Deals'));
    await tester.pumpAndSettle();
    expect(find.text('Bakery · Deals near HSR Layout'), findsOneWidget);
  });

  testWidgets('All Bengaluru switches the home screen to city-wide shops', (tester) async {
    final requests = <Uri>[];
    await _pumpApp(tester, _api(requests));
    await tester.tap(find.text('All Bengaluru'));
    await tester.pumpAndSettle();
    expect(find.text('DEALS IN BENGALURU'), findsOneWidget);
    expect(requests.any((u) => u.path == '/api/discovery/bangalore/shops'), isTrue);
    expect(requests.any((u) => u.queryParameters['scope'] == 'CITYWIDE'), isTrue);
  });

  testWidgets('Following asks a signed-out customer to sign in', (tester) async {
    await _pumpApp(tester, _api([]));
    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(find.text('Follow the shops you like'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });
}
