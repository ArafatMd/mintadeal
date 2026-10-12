import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cart.dart';
import 'cart_screen.dart';

class CartButton extends ConsumerWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);
    return IconButton(
      tooltip: 'Cart',
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_bag_outlined),
      ),
    );
  }
}
