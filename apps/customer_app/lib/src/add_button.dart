import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'cart.dart';

/// The ADD button on a product: outlined until the item is in the cart, then a red − quantity + stepper.
class AddButton extends ConsumerWidget {
  const AddButton({super.key, required this.item, this.width = 78, this.height = 34});

  final DiscoveryItem item;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = item.listing.id;
    final quantity = ref.watch(cartProvider.select((c) => c.where((e) => e.listingId == id).fold(0, (s, e) => s + e.quantity)));
    final cart = ref.read(cartProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(8);
    final label = Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4);
    final available = item.deliverable || item.pickupAvailable || item.venueOffer;

    if (!available) {
      return Tooltip(
        message: 'Not available in your area',
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: radius, border: Border.all(color: scheme.outlineVariant)),
          child: Text('ADD', style: label?.copyWith(color: scheme.outline)),
        ),
      );
    }

    if (quantity == 0) {
      return SizedBox(
        width: width,
        height: height,
        child: Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: scheme.primary, width: 1.3)),
          child: InkWell(
            borderRadius: radius,
            onTap: () => cart.add(item),
            child: Semantics(
              button: true,
              label: 'Add ${item.listing.title}',
              excludeSemantics: true,
              child: Center(child: Text('ADD', style: label?.copyWith(color: scheme.primary))),
            ),
          ),
        ),
      );
    }

    Widget step(IconData icon, String tooltip, VoidCallback? onTap) => Expanded(
          child: Tooltip(
            message: tooltip,
            child: InkWell(
              onTap: onTap,
              child: SizedBox.expand(child: Icon(icon, size: 18, color: scheme.onPrimary)),
            ),
          ),
        );

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: scheme.primary,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Row(children: [
          step(Icons.remove, quantity == 1 ? 'Remove' : 'Less', () => cart.setQuantity(id, quantity - 1)),
          Text('$quantity', style: label?.copyWith(color: scheme.onPrimary)),
          step(Icons.add, 'More',
              quantity >= CartController.maxQuantity ? null : () => cart.setQuantity(id, quantity + 1)),
        ]),
      ),
    );
  }
}
