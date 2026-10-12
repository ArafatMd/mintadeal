import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';
import 'package:url_launcher/url_launcher.dart';

import 'cart_button.dart';
import 'listing_card.dart';
import 'providers.dart';
import 'sign_in.dart';

class StorefrontScreen extends ConsumerWidget {
  const StorefrontScreen({super.key, required this.vendorId, this.at});

  final String vendorId;
  final GeoPoint? at;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = placeKey(vendorId, at);
    final store = ref.watch(storefrontProvider(key));
    return Scaffold(
      appBar: AppBar(title: Text(store.value?.vendor.displayName ?? ''), actions: const [CartButton()]),
      body: AsyncView(
        value: store,
        onRetry: () => ref.invalidate(storefrontProvider(key)),
        data: (s) => RefreshIndicator(
          onRefresh: () => ref.refresh(storefrontProvider(key).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              _Header(store: s, onFollow: () => _toggleFollow(context, ref, s, key)),
              const SizedBox(height: 20),
              Text('Products and offers', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (s.listings.isEmpty)
                const EmptyView(icon: Icons.inventory_2_outlined, title: 'No live listings right now'),
              for (final item in s.listings) ...[
                ListingCard(item: item, at: at, showVendor: false),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFollow(BuildContext context, WidgetRef ref, Storefront s, PlaceKey key) async {
    if (!await ensureSignedIn(context, ref)) return;
    try {
      final api = ref.read(apiProvider);
      s.followed ? await api.unfollow(s.vendor.id) : await api.follow(s.vendor.id);
      ref.invalidate(storefrontProvider(key));
      ref.invalidate(followsProvider);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.store, required this.onFollow});

  final Storefront store;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final v = store.vendor;
    final theme = Theme.of(context);
    final delivery = [
      if (v.selfDelivery || v.partnerDelivery)
        v.citywideDelivery
            ? 'Delivers across Bangalore'
            : 'Delivers within ${v.deliveryRadiusKm.toStringAsFixed(v.deliveryRadiusKm % 1 == 0 ? 0 : 1)} km',
      if (v.pickup) 'Pickup available',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          CatalogueImage(url: v.logoUrl, category: v.category, size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.displayName, style: theme.textTheme.titleLarge),
              Text([v.category.label, v.area, if (store.distanceKm != null) formatDistance(store.distanceKm!)].join(' · '),
                  style: theme.textTheme.bodySmall),
              if (v.mintadealOwn) Text('Sold by Mintadeal', style: theme.textTheme.labelSmall),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: store.followed
                ? OutlinedButton.icon(onPressed: onFollow, icon: const Icon(Icons.favorite), label: const Text('Following'))
                : FilledButton.icon(onPressed: onFollow, icon: const Icon(Icons.favorite_border), label: const Text('Follow')),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: 'Call shop',
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: v.phone)),
            icon: const Icon(Icons.call_outlined),
          ),
        ]),
        const SizedBox(height: 4),
        Text('${store.followers} ${store.followers == 1 ? 'follower' : 'followers'}', style: theme.textTheme.bodySmall),
        if (v.description != null) ...[const SizedBox(height: 12), Text(v.description!)],
        const SizedBox(height: 12),
        _Info(icon: Icons.place_outlined, text: '${v.addressLine}, ${v.area}'),
        if (v.openingHours != null) _Info(icon: Icons.schedule, text: v.openingHours!),
        if (delivery.isNotEmpty) _Info(icon: Icons.delivery_dining_outlined, text: delivery.join(' · ')),
        if (v.minOrderMinor > 0) _Info(icon: Icons.shopping_basket_outlined, text: 'Minimum order ${formatInr(v.minOrderMinor)}'),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ]),
    );
  }
}
