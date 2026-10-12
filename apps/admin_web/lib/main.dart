import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'src/admin_shell.dart';

void main() {
  runApp(const ProviderScope(retry: _noRetry, child: AdminApp()));
}

Duration? _noRetry(int retryCount, Object error) => null;

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mintadeal Admin',
      debugShowCheckedModeBanner: false,
      theme: mintadealTheme(),
      darkTheme: mintadealTheme(brightness: Brightness.dark),
      home: AuthGate(
        signedOut: const PhoneLoginScreen(
          appTitle: 'Admin',
          tagline: 'Review shops, moderate listings, manage staff.',
          requiredRole: Role.ADMIN,
        ),
        signedIn: (_) => const AdminShell(),
      ),
    );
  }
}
