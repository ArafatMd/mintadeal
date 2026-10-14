import 'package:flutter/material.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'add_button.dart';
import 'listing_detail_screen.dart';

/// How many product tiles fit side by side: two on a phone, more on wider screens.
int productColumns(double width) => (width / 175).floor().clamp(2, 6);

/// A product or offer in the grid: image with discount badge, how you get it, title, shop, price and ADD.
class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.item, this.at, this.showVendor = true});

  final DiscoveryItem item;
  final GeoPoint? at;
  final bool showVendor;

  @override
  Widget build(BuildContext context) {
    final l = item.listing;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasOffer = l.offerPriceMinor != null && l.offerPriceMinor! < l.priceMinor;
    final percent = hasOffer ? ((l.priceMinor - l.offerPriceMinor!) * 100 / l.priceMinor).round() : 0;
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.25);
    // Two lines of title, so every tile in a row lines up.
    final titleHeight = MediaQuery.textScalerOf(context).scale(titleStyle?.fontSize ?? 14) * 1.25 * 2 + 2;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ListingDetailScreen(listingId: l.id, at: at),
        )),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Stack(children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                color: theme.brightness == Brightness.light ? MintadealColors.imageWell : scheme.surfaceContainerHigh,
                child: l.imageUrl == null
                    ? Icon(l.category.icon, size: 48, color: scheme.outline)
                    : Image.network(l.imageUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(l.category.icon, size: 48, color: scheme.outline)),
              ),
            ),
            if (hasOffer) Positioned(top: 0, left: 8, child: _OffBadge(percent: percent)),
            if (item.venueOffer)
              Positioned(
                left: 6,
                bottom: 6,
                child: _Tag(text: 'VENUE OFFER', color: MintadealColors.yellow, textColor: MintadealColors.charcoal),
              ),
            if (item.followed)
              Positioned(
                top: 6,
                right: 6,
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: scheme.surface,
                  child: Icon(Icons.favorite, size: 15, color: scheme.primary),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _HowYouGetIt(item: item),
              const SizedBox(height: 6),
              SizedBox(
                height: titleHeight,
                child: Text(l.title, style: titleStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              if (showVendor)
                Text(
                  [item.vendor.displayName, ?item.distanceText].join(' · '),
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(formatInr(hasOffer ? l.offerPriceMinor! : l.priceMinor),
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    if (hasOffer)
                      Text(formatInr(l.priceMinor),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.outline,
                            decoration: TextDecoration.lineThrough,
                          )),
                  ]),
                ),
                AddButton(item: item, width: 72),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Products laid out in rows of [productColumns], for screens that are not paged.
class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key, required this.items, this.at, this.showVendor = true, this.gap = 10});

  final List<DiscoveryItem> items;
  final GeoPoint? at;
  final bool showVendor;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final n = productColumns(constraints.maxWidth);
      return Column(children: [
        for (var start = 0; start < items.length; start += n) ...[
          if (start > 0) SizedBox(height: gap),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = start; i < start + n; i++) ...[
              if (i > start) SizedBox(width: gap),
              Expanded(
                child: i < items.length
                    ? ProductTile(item: items[i], at: at, showVendor: showVendor)
                    : const SizedBox.shrink(),
              ),
            ],
          ]),
        ],
      ]);
    });
  }
}

/// The ribbon-style "12% OFF" badge hanging from the top of the image.
class _OffBadge extends StatelessWidget {
  const _OffBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
      ),
      child: Text('$percent%\nOFF',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w800,
                height: 1.05,
                fontSize: 10,
              )),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color, required this.textColor});

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 9.5,
                letterSpacing: 0.3,
              )),
    );
  }
}

/// One small grey chip saying how the customer gets it: delivery (with fee), pickup or at the venue.
class _HowYouGetIt extends StatelessWidget {
  const _HowYouGetIt({required this.item});

  final DiscoveryItem item;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = item.venueOffer
        ? (Icons.qr_code_2, 'Use at venue')
        : item.deliverable
            ? (
                Icons.delivery_dining_outlined,
                item.deliveryFeeMinor == null || item.deliveryFeeMinor == 0
                    ? 'Free delivery'
                    : 'Delivery ${formatInr(item.deliveryFeeMinor!)}'
              )
            : item.pickupAvailable
                ? (Icons.storefront_outlined, 'Pickup')
                : (Icons.block, 'Not in your area');
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: scheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                  )),
        ),
      ]),
    );
  }
}
