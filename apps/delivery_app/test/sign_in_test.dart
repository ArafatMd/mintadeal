import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mintadeal_delivery/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('signed-out users see the phone sign-in screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: DeliveryApp()));
    await tester.pumpAndSettle();
    expect(find.text('Delivery partners'), findsOneWidget);
    expect(find.text('Mobile number'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
  });
}
