import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mintadeal_core/mintadeal_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('when the SMS does not arrive, the code can be sent on WhatsApp', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final requests = <Map<String, dynamic>>[];
    final client = MockClient((req) async {
      requests.add(jsonDecode(req.body) as Map<String, dynamic>);
      return http.Response(jsonEncode({'channel': requests.last['channel'] ?? 'SMS', 'whatsApp': true}), 202,
          headers: {'content-type': 'application/json'});
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(MintadealApi(ApiClient(baseUrl: 'http://test', token: () => null, httpClient: client))),
      ],
      child: MaterialApp(theme: mintadealTheme(), home: const PhoneLoginScreen(appTitle: 'Mintadeal', tagline: '')),
    ));
    await tester.enterText(find.byType(TextField).first, '9844400002');
    await tester.tap(find.text('Send code'));
    await tester.pump();
    expect(find.textContaining('Code sent by SMS'), findsOneWidget);
    expect(find.textContaining('ask again in 30 s'), findsOneWidget);
    expect(find.text('Get the code on WhatsApp'), findsNothing);

    await tester.pump(const Duration(seconds: 31));
    await tester.tap(find.text('Get the code on WhatsApp'));
    await tester.pump();
    expect(requests.last['channel'], 'WHATSAPP');
    expect(find.textContaining('Code sent on WhatsApp'), findsOneWidget);

    // Leave no countdown running.
    await tester.pump(const Duration(seconds: 31));
    expect(find.text('Get the code on WhatsApp'), findsNothing);
    expect(find.text('Send the code by SMS again'), findsOneWidget);
  });
}
