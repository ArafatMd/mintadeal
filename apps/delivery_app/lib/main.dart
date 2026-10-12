import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'src/delivery_home.dart';

void main() {
  runApp(const ProviderScope(retry: _noRetry, child: DeliveryApp()));
}

Duration? _noRetry(int retryCount, Object error) => null;

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mintadeal Delivery',
      debugShowCheckedModeBanner: false,
      theme: mintadealTheme(),
      darkTheme: mintadealTheme(brightness: Brightness.dark),
      home: AuthGate(
        signedOut: const PhoneLoginScreen(
          appTitle: 'Delivery partners',
          tagline: 'Pick up from local shops and deliver to customers nearby.',
          requiredRole: Role.DELIVERY_AGENT,
        ),
        signedIn: (session) => DeliveryHome(user: session.user),
      ),
    );
  }
}
