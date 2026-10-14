import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'banners_page.dart';
import 'delivery_page.dart';
import 'listings_page.dart';
import 'money_page.dart';
import 'notifications_page.dart';
import 'payouts_page.dart';
import 'orders_page.dart';
import 'settings_page.dart';
import 'stage6_pages.dart';
import 'users_page.dart';
import 'vendors_page.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _index = 0;

  static const _destinations = [
    (Icons.space_dashboard_outlined, Icons.space_dashboard, 'Overview'),
    (Icons.storefront_outlined, Icons.storefront, 'Vendors'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Orders'),
    (Icons.support_agent_outlined, Icons.support_agent, 'Support'),
    (Icons.delivery_dining_outlined, Icons.delivery_dining, 'Delivery'),
    (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Money'),
    (Icons.payments_outlined, Icons.payments, 'Payouts'),
    (Icons.sell_outlined, Icons.sell, 'Listings'),
    (Icons.star_outline_rounded, Icons.star_rounded, 'Reviews'),
    (Icons.view_carousel_outlined, Icons.view_carousel, 'Banners'),
    (Icons.chat_outlined, Icons.chat, 'Messages'),
    (Icons.settings_outlined, Icons.settings, 'Integrations'),
    (Icons.badge_outlined, Icons.badge, 'Staff & roles'),
  ];

  Widget _page(int i) => switch (_destinations[i].$3) {
    'Overview' => OverviewPage(
      onOpen: (label) => setState(() {
        _index = _destinations.indexWhere((d) => d.$3 == label);
      }),
    ),
    'Vendors' => const VendorsPage(),
    'Orders' => const OrdersPage(),
    'Support' => const SupportPage(),
    'Delivery' => const DeliveryPage(),
    'Money' => const MoneyPage(),
    'Payouts' => const PayoutsPage(),
    'Listings' => const ListingsPage(),
    'Reviews' => const ReviewsPage(),
    'Banners' => const BannersPage(),
    'Messages' => const NotificationsPage(),
    'Integrations' => const SettingsPage(),
    _ => const UsersPage(),
  };

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).value?.user;
    final wide = MediaQuery.of(context).size.width >= 900;
    const destinations = _destinations;
    final signOut = IconButton(
      tooltip: 'Sign out ${user?.phone ?? ''}',
      icon: const Icon(Icons.logout),
      onPressed: () => ref.read(sessionProvider.notifier).signOut(),
    );
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const MintadealLogo(height: 36),
            const SizedBox(width: 12),
            Text(
              'Admin',
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Tooltip(
                message: 'Your profile photo',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Your profile'),
                      content: const SizedBox(width: 420, child: ProfilePhotoCard(subtitle: 'Mintadeal admin')),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                    ),
                  ),
                  child: UserAvatar(url: user.avatarUrl, name: user.name, radius: 16),
                ),
              ),
            ),
          signOut,
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Thirteen pages do not fit on a short screen, so the menu scrolls.
          LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: IntrinsicHeight(
                  child: NavigationRail(
                    extended: wide,
                    selectedIndex: _index,
                    onDestinationSelected: (i) => setState(() => _index = i),
                    labelType: wide ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                    destinations: [
                      for (final (icon, selected, label) in destinations)
                        NavigationRailDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: Text(label)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _page(_index)),
        ],
      ),
    );
  }
}
