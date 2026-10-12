import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'listings_tab.dart';
import 'order_alerts.dart';
import 'orders_tab.dart';
import 'providers.dart';
import 'shop_form_screen.dart';

/// Routes the shop owner by the state of their shop: register, wait for review, or run the shop.
class VendorHome extends ConsumerWidget {
  const VendorHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(myShopProvider);
    return AsyncView(
      value: shop,
      onRetry: () => ref.invalidate(myShopProvider),
      data: (shop) => switch (shop?.status) {
        null => const ShopFormScreen(existing: null),
        VendorStatus.APPROVED => _Dashboard(shop: shop!),
        _ => _ReviewStatusScreen(shop: shop!),
      },
    );
  }
}

class _ReviewStatusScreen extends ConsumerWidget {
  const _ReviewStatusScreen({required this.shop});

  final Vendor shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, title, message) = switch (shop.status) {
      VendorStatus.PENDING => (
          Icons.hourglass_top,
          'Your shop is being reviewed',
          'Mintadeal checks every shop before it goes live. We will call you on ${shop.phone} if we need anything.'
        ),
      VendorStatus.REJECTED => (
          Icons.report_outlined,
          'Your application needs changes',
          shop.reviewNote ?? 'Update your details and submit again.'
        ),
      _ => (
          Icons.block,
          'Your shop is suspended',
          '${shop.reviewNote ?? ''}\nContact Mintadeal support to restore it.'.trim()
        ),
    };
    return Scaffold(
      appBar: AppBar(title: Text(shop.displayName), actions: [_SignOutButton()]),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myShopProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 40),
            EmptyView(
              icon: icon,
              title: title,
              message: message,
              action: shop.status == VendorStatus.SUSPENDED
                  ? null
                  : OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(shop.status == VendorStatus.REJECTED ? 'Fix and resubmit' : 'Edit details'),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ShopFormScreen(existing: shop),
                      )),
                    ),
            ),
            const SizedBox(height: 16),
            Center(child: StatusChip(label: shop.status.label, color: vendorStatusColor(shop.status))),
            const SizedBox(height: 8),
            const Center(child: Text('Pull down to refresh')),
          ],
        ),
      ),
    );
  }
}

class _Dashboard extends ConsumerStatefulWidget {
  const _Dashboard({required this.shop});

  final Vendor shop;

  @override
  ConsumerState<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<_Dashboard> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    newOrderTick.addListener(_alert);
  }

  @override
  void dispose() {
    newOrderTick.removeListener(_alert);
    super.dispose();
  }

  void _alert() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('New order received'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(label: 'View', onPressed: () => setState(() => _tab = 1)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final newOrders = ref.watch(orderCountsProvider)?.newOrders ?? 0;
    final pages = [
      ListingsTab(shop: widget.shop),
      const OrdersTab(),
      _ShopTab(shop: widget.shop),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.sell_outlined), selectedIcon: Icon(Icons.sell), label: 'Listings'),
          NavigationDestination(
            icon: Badge(isLabelVisible: newOrders > 0, label: Text('$newOrders'), child: const Icon(Icons.receipt_long_outlined)),
            selectedIcon: Badge(isLabelVisible: newOrders > 0, label: Text('$newOrders'), child: const Icon(Icons.receipt_long)),
            label: 'Orders',
          ),
          const NavigationDestination(
              icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'My shop'),
        ],
      ),
    );
  }
}

class _ShopTab extends ConsumerWidget {
  const _ShopTab({required this.shop});

  final Vendor shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).value?.user;
    final ways = [
      if (shop.selfDelivery) 'Shop delivery',
      if (shop.partnerDelivery) 'Partner delivery',
      if (shop.pickup) 'Pickup',
      if (shop.citywideDelivery) 'Delivers across Bangalore',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('My shop'), actions: [_SignOutButton()]),
      body: ListView(
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Center(child: MintadealLogo(height: 56))),
          ListTile(
            leading: CatalogueImage(url: shop.json['logoUrl'] as String?, category: shop.category, size: 48),
            title: Text(shop.displayName),
            subtitle: Text('${shop.category.label} · ${shop.area}'),
            trailing: StatusChip(label: shop.status.label, color: vendorStatusColor(shop.status)),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Shop details and delivery settings'),
            subtitle: Text(ways.isEmpty ? 'Venue offers only' : ways.join(' · ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopFormScreen(existing: shop))),
          ),
          if (shop.vendorType == VendorType.INTERNAL)
            const ListTile(leading: Icon(Icons.verified_outlined), title: Text('Mintadeal own catalogue')),
          const Divider(),
          ListTile(leading: const Icon(Icons.phone_outlined), title: const Text('Signed in as'), subtitle: Text(user?.phone ?? '')),
        ],
      ),
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Sign out',
      icon: const Icon(Icons.logout),
      onPressed: () => ref.read(sessionProvider.notifier).signOut(),
    );
  }
}
