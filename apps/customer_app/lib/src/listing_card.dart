import 'package:flutter/material.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'listing_detail_screen.dart';

class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.item, this.at, this.showVendor = true});

  final DiscoveryItem item;
  final GeoPoint? at;
  final bool showVendor;

  @override
  Widget build(BuildContext context) {
    final l = item.listing;
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ListingDetailScreen(listingId: l.id, at: at),
        )),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CatalogueImage(url: l.imageUrl, category: l.category, size: 84),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.title, style: theme.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (showVendor) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        if (item.followed) ...[
                          Icon(Icons.favorite, size: 14, color: theme.colorScheme.secondary),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            [
                              item.vendor.displayName,
                              if (item.distanceKm != null) formatDistance(item.distanceKm!),
                            ].join(' · '),
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 6),
                    PriceTag(priceMinor: l.priceMinor, offerPriceMinor: l.offerPriceMinor),
                    const SizedBox(height: 6),
                    _Availability(item: item),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Availability extends StatelessWidget {
  const _Availability({required this.item});

  final DiscoveryItem item;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    final parts = <(IconData, String)>[
      if (item.venueOffer) (Icons.qr_code_2, 'Use at venue'),
      if (item.deliverable)
        (Icons.delivery_dining_outlined,
            item.deliveryFeeMinor == null || item.deliveryFeeMinor == 0
                ? 'Free delivery'
                : 'Delivery ${formatInr(item.deliveryFeeMinor!)}'),
      if (item.pickupAvailable) (Icons.storefront_outlined, 'Pickup'),
    ];
    return Wrap(spacing: 10, runSpacing: 2, children: [
      for (final (icon, text) in parts)
        Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14), const SizedBox(width: 3), Text(text, style: style)]),
    ]);
  }
}
