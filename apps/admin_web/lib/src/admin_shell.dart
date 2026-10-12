import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'listings_page.dart';
import 'orders_page.dart';
import 'settings_page.dart';
import 'users_page.dart';
import 'vendors_page.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _index = 0;

  static const _pages = [VendorsPage(), OrdersPage(), ListingsPage(), SettingsPage(), UsersPage()];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).value?.user;
    final wide = MediaQuery.of(context).size.width >= 900;
    final destinations = const [
      (Icons.storefront_outlined, Icons.storefront, 'Vendors'),
      (Icons.receipt_long_outlined, Icons.receipt_long, 'Orders'),
      (Icons.sell_outlined, Icons.sell, 'Listings'),
      (Icons.settings_outlined, Icons.settings, 'Integrations'),
      (Icons.badge_outlined, Icons.badge, 'Staff & roles'),
    ];
    final signOut = IconButton(
      tooltip: 'Sign out ${user?.phone ?? ''}',
      icon: const Icon(Icons.logout),
      onPressed: () => ref.read(sessionProvider.notifier).signOut(),
    );
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const MintadealLogo(height: 36),
          const SizedBox(width: 12),
          Text('Admin', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
        ]),
        actions: [signOut, const SizedBox(width: 8)],
      ),
      body: Row(children: [
        NavigationRail(
          extended: wide,
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          labelType: wide ? NavigationRailLabelType.none : NavigationRailLabelType.all,
          destinations: [
            for (final (icon, selected, label) in destinations)
              NavigationRailDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: Text(label)),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _pages[_index]),
      ]),
    );
  }
}
