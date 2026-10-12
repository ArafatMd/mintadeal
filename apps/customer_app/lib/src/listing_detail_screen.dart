import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'providers.dart';
import 'storefront_screen.dart';

class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({super.key, required this.listingId, this.at});

  final String listingId;
  final GeoPoint? at;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = placeKey(listingId, at);
    final item = ref.watch(listingProvider(key));
    return Scaffold(
      appBar: AppBar(),
      body: AsyncView(
        value: item,
        onRetry: () => ref.invalidate(listingProvider(key)),
        data: (item) => _Detail(item: item, at: at),
      ),
      bottomNavigationBar: item.value == null ? null : _OrderBar(item: item.value!),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.item, required this.at});

  final DiscoveryItem item;
  final GeoPoint? at;

  @override
  Widget build(BuildContext context) {
    final l = item.listing;
    final theme = Theme.of(context);
    final dates = DateFormat('d MMM yyyy');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Center(child: CatalogueImage(url: l.imageUrl, category: l.category, size: 240, radius: 16)),
        const SizedBox(height: 16),
        Text(l.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        PriceTag(priceMinor: l.priceMinor, offerPriceMinor: l.offerPriceMinor, large: true),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: CatalogueImage(url: item.vendor.logoUrl, category: item.vendor.category, size: 44),
            title: Text(item.vendor.displayName),
            subtitle: Text([
              item.vendor.area,
              if (item.distanceKm != null) '${formatDistance(item.distanceKm!)} away',
              if (item.vendor.mintadealOwn) 'Sold by Mintadeal',
            ].join(' · ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => StorefrontScreen(vendorId: item.vendor.id, at: at),
            )),
          ),
        ),
        const SizedBox(height: 16),
        Text('How you get it', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (item.venueOffer)
          const _Way(icon: Icons.qr_code_2, title: 'Use at the venue',
              subtitle: 'After you buy, you get a QR code. Show it at the venue to use the offer.'),
        if (item.deliverable)
          _Way(
            icon: Icons.delivery_dining_outlined,
            title: 'Delivery to your area',
            subtitle: item.deliveryFeeMinor == null || item.deliveryFeeMinor == 0
                ? 'Free delivery'
                : 'Delivery fee ${formatInr(item.deliveryFeeMinor!)}',
          ),
        if (item.pickupAvailable)
          const _Way(icon: Icons.storefront_outlined, title: 'Pickup from the shop',
              subtitle: 'Collect it yourself when the shop says it is ready.'),
        if (!item.deliverable && !item.pickupAvailable && !item.venueOffer)
          const _Way(icon: Icons.info_outline, title: 'Not available in your area',
              subtitle: 'This shop does not deliver to the area you chose.'),
        if (l.listingType == ListingType.OFFER && (l.validFrom != null || l.validTo != null)) ...[
          const SizedBox(height: 8),
          _Way(
            icon: Icons.event_available_outlined,
            title: 'Valid',
            subtitle: [
              if (l.validFrom != null) 'from ${dates.format(l.validFrom!)}',
              if (l.validTo != null) 'until ${dates.format(l.validTo!)}',
            ].join(' '),
          ),
        ],
        if (l.stock != null && l.stock! <= 5)
          _Way(icon: Icons.inventory_2_outlined, title: 'Only ${l.stock} left', subtitle: 'Limited stock at the shop'),
        if (l.description != null) ...[
          const SizedBox(height: 16),
          Text('About', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(l.description!),
        ],
        if (l.terms != null) ...[
          const SizedBox(height: 16),
          Text('Terms', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(l.terms!),
        ],
      ],
    );
  }
}

class _Way extends StatelessWidget {
  const _Way({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

class _OrderBar extends StatelessWidget {
  const _OrderBar({required this.item});

  final DiscoveryItem item;

  @override
  Widget build(BuildContext context) {
    final available = item.deliverable || item.pickupAvailable || item.venueOffer;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          icon: Icon(item.venueOffer ? Icons.qr_code_2 : Icons.shopping_bag_outlined),
          label: Text(available ? (item.venueOffer ? 'Buy offer' : 'Add to cart') : 'Not available here'),
          // Checkout arrives in Stage 3 (orders); until then explain rather than fail silently.
          onPressed: available
              ? () => showMessage(context, 'Ordering opens in the next update. Follow the shop to hear first.')
              : null,
        ),
      ),
    );
  }
}
