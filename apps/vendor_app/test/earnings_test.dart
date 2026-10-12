import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mintadeal_core/mintadeal_core.dart';
import 'package:mintadeal_vendor/src/earnings_tab.dart';

void main() {
  testWidgets('earnings show the balance, commission, statement and payouts', (tester) async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'balanceMinor': 95000,
            'inPayoutMinor': 0,
            'payoutDestination': 'UPI lakshmi@okbank',
            'commissionBps': 500,
            'statement': [
              {'type': 'COMMISSION', 'description': 'Commission 5% on MD-ABC-1', 'amountMinor': -5000, 'createdAt': '2026-10-12T10:00:00Z'},
              {'type': 'SETTLEMENT', 'description': 'Order MD-ABC-1 (paid online)', 'amountMinor': 100000, 'createdAt': '2026-10-12T10:00:00Z'},
            ],
            'payouts': [
              {
                'id': 'p1', 'vendorId': 'v1', 'vendorName': 'Lakshmi', 'amountMinor': 40000, 'status': 'PAID',
                'method': 'MANUAL', 'destination': 'UPI lakshmi@okbank', 'utr': 'HDFC123', 'createdAt': '2026-10-01T10:00:00Z',
                'paidAt': '2026-10-02T10:00:00Z',
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));
    final shop = Vendor({
      'id': 'v1', 'displayName': 'Lakshmi Stores', 'category': 'GROCERY', 'vendorType': 'EXTERNAL', 'status': 'APPROVED',
      'phone': '+919876543210', 'area': 'HSR Layout', 'addressLine': '1 Main', 'createdAt': '2026-10-01T10:00:00Z',
      'selfDelivery': false, 'partnerDelivery': false, 'pickup': true, 'citywideDelivery': false,
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(MintadealApi(ApiClient(baseUrl: 'http://t', token: () => null, httpClient: client))),
      ],
      child: MaterialApp(theme: mintadealTheme(), home: EarningsTab(shop: shop)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mintadeal owes you'), findsOneWidget);
    expect(find.text('₹950'), findsOneWidget);
    expect(find.text('Mintadeal commission: 5%'), findsOneWidget);
    expect(find.text('−₹50'), findsOneWidget);
    expect(find.text('+₹1,000'), findsOneWidget);
    expect(find.textContaining('Ref HDFC123'), findsOneWidget);
  });
}
