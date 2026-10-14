import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../util/money.dart';

/// Shows a snackbar for an error, using the API's message when available.
void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$error'), behavior: SnackBarBehavior.floating));
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

/// Price with the original struck through when there is a genuine offer.
class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.priceMinor, this.offerPriceMinor, this.large = false});

  final int priceMinor;
  final int? offerPriceMinor;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final main = large ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium;
    final hasOffer = offerPriceMinor != null && offerPriceMinor! < priceMinor;
    final percent = hasOffer ? ((priceMinor - offerPriceMinor!) * 100 / priceMinor).round() : 0;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Text(formatInr(hasOffer ? offerPriceMinor! : priceMinor),
            style: main?.copyWith(fontWeight: FontWeight.w700)),
        if (hasOffer) ...[
          Text(formatInr(priceMinor),
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.outline,
              )),
          DealBadge(text: '$percent% off'),
        ],
      ],
    );
  }
}

class DealBadge extends StatelessWidget {
  const DealBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              )),
    );
  }
}

/// A listing or shop image with a category icon placeholder.
class CatalogueImage extends StatelessWidget {
  const CatalogueImage({super.key, required this.url, required this.category, this.size = 72, this.radius = 10});

  final String? url;
  final VendorCategory category;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: size,
      height: size,
      color: scheme.tertiaryContainer,
      child: Icon(category.icon, color: scheme.onTertiaryContainer.withValues(alpha: 0.7), size: size * 0.45),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? placeholder
          : Image.network(url!, width: size, height: size, fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
    );
  }
}

Color vendorStatusColor(VendorStatus s) => switch (s) {
      VendorStatus.PENDING => Colors.orange.shade800,
      VendorStatus.APPROVED => Colors.green.shade700,
      VendorStatus.REJECTED => Colors.red.shade700,
      VendorStatus.SUSPENDED => Colors.grey.shade700,
    };

Color listingStatusColor(ListingStatus s) => switch (s) {
      ListingStatus.DRAFT => Colors.blueGrey,
      ListingStatus.ACTIVE => Colors.green.shade700,
      ListingStatus.PAUSED => Colors.orange.shade800,
      ListingStatus.REMOVED => Colors.red.shade700,
    };

/// Small icon + text row for fulfilment options.
class FulfilmentChips extends StatelessWidget {
  const FulfilmentChips({super.key, required this.modes});

  final List<FulfilmentMode> modes;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final m in modes)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(m.icon, size: 16),
            const SizedBox(width: 4),
            Text(m.label, style: style),
          ]),
      ],
    );
  }
}
