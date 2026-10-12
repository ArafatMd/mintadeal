import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mintadeal_core/mintadeal_core.dart';
import 'package:mintadeal_delivery/src/delivery_home.dart';

Map<String, dynamic> _job() => {
      'id': 'j1',
      'orderCode': 'MD-7K3Q9P-1',
      'status': 'REQUESTED',
      'distanceKm': 1.4,
      'itemCount': 2,
      'cashToCollectMinor': 58000,
      'pickup': {'name': 'HSR Fresh Meats', 'phone': null, 'address': '14th Cross', 'area': 'HSR Layout', 'latitude': 12.9, 'longitude': 77.6},
      'drop': {'name': null, 'phone': null, 'address': null, 'area': 'HSR Layout', 'latitude': 12.91, 'longitude': 77.65},
      'mine': false,
      'requestedAt': '2026-10-12T10:00:00Z',
    };

void main() {
  testWidgets('new jobs show the trip, cash to collect, and no customer details', (tester) async {
    final client = MockClient((req) async => http.Response(
          jsonEncode(req.url.path.endsWith('/available') ? [_job()] : []),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(MintadealApi(ApiClient(baseUrl: 'http://t', token: () => null, httpClient: client))),
      ],
      child: MaterialApp(
        theme: mintadealTheme(),
        home: DeliveryHome(user: AppUser(id: 'u1', phone: '+919000000201', name: 'Ravi', roles: const [Role.DELIVERY_AGENT])),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('HSR Fresh Meats'), findsOneWidget);
    expect(find.textContaining('Collect ₹580 cash'), findsOneWidget);
    expect(find.textContaining('1.4 km'), findsOneWidget);
    expect(find.text('Ravi'), findsOneWidget);
  });
}
