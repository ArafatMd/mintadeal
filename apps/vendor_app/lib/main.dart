import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'src/vendor_home.dart';

void main() {
  runApp(const ProviderScope(retry: _noRetry, child: VendorApp()));
}

Duration? _noRetry(int retryCount, Object error) => null;

class VendorApp extends StatelessWidget {
  const VendorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mintadeal for Shops',
      debugShowCheckedModeBanner: false,
      theme: mintadealTheme(),
      darkTheme: mintadealTheme(brightness: Brightness.dark),
      home: AuthGate(
        signedOut: const PhoneLoginScreen(
          appTitle: 'Mintadeal for Shops',
          tagline: 'Reach every customer in your area. Post deals, get orders.',
        ),
        signedIn: (_) => const VendorHome(),
      ),
    );
  }
}
