import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

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
        signedIn: (session) => JobsScreen(user: session.user),
      ),
    );
  }
}

/// Assigned delivery jobs. Jobs are created by partner-delivery bookings, which arrive with the delivery stage.
class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My jobs'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Column(children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.delivery_dining)),
          title: Text(user.name ?? 'Delivery partner'),
          subtitle: Text(user.phone),
        ),
        const Divider(height: 1),
        const Expanded(
          child: EmptyView(
            icon: Icons.route_outlined,
            title: 'No jobs assigned',
            message: 'When a shop requests a Mintadeal delivery partner, the pickup and drop details appear here.',
          ),
        ),
      ]),
    );
  }
}
