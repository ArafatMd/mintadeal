import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'src/home_screen.dart';

void main() {
  runApp(const ProviderScope(retry: _noRetry, child: CustomerApp()));
}

Duration? _noRetry(int retryCount, Object error) => null;

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mintadeal',
      debugShowCheckedModeBanner: false,
      theme: mintadealTheme(),
      darkTheme: mintadealTheme(brightness: Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
