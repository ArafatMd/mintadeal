import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'cart.dart';
import 'cart_screen.dart';

/// The red "View cart" bar shown above the navigation while the cart has items.
class CartBar extends ConsumerWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    if (cart.isEmpty) return const SizedBox.shrink();
    final count = cart.fold(0, (s, e) => s + e.quantity);
    // For display only: checkout always uses the server's prices.
    final total = cart.fold(0, (s, e) => s + (e.offerPriceMinor ?? e.priceMinor) * e.quantity);
    final saved = cart.fold(0, (s, e) {
      final offer = e.offerPriceMinor;
      return offer != null && offer < e.priceMinor ? s + (e.priceMinor - offer) * e.quantity : s;
    });
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final onRed = scheme.onPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Material(
        color: scheme.primary,
        elevation: 4,
        shadowColor: scheme.primary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: onRed.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.shopping_bag_outlined, color: onRed),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('$count ${count == 1 ? 'item' : 'items'} · ${formatInr(total)}',
                      style: text.titleSmall?.copyWith(color: onRed, fontWeight: FontWeight.w800)),
                  if (saved > 0)
                    Text('You save ${formatInr(saved)}',
                        style: text.labelSmall?.copyWith(color: onRed, fontWeight: FontWeight.w600)),
                ]),
              ),
              Text('View cart', style: text.titleSmall?.copyWith(color: onRed, fontWeight: FontWeight.w800)),
              Icon(Icons.chevron_right, color: onRed),
            ]),
          ),
        ),
      ),
    );
  }
}
