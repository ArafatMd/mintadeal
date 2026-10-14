import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'area.dart';
import 'cart_bar.dart';
import 'cart_button.dart';
import 'product_tile.dart';

/// "See all": every deal (not grouped by shop) for the same scope and filters as the home screen.
class AllDealsScreen extends ConsumerWidget {
  const AllDealsScreen({super.key, required this.nearby, this.category, this.type, this.query = ''});

  final bool nearby;
  final VendorCategory? category;
  final ListingType? type;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = ref.watch(areaProvider);
    final api = ref.watch(apiProvider);
    final signedIn = ref.watch(sessionProvider).value != null;
    return Scaffold(
      appBar: AppBar(
        title: Text([
          if (category != null) category!.label,
          nearby ? 'Deals near ${area.name}' : 'Deals across Bengaluru',
        ].join(' · ')),
        actions: const [CartButton(), SizedBox(width: 4)],
      ),
      body: PagedList<DiscoveryItem>(
        queryKey: (nearby, area.lat, area.lng, category, type, query, signedIn),
        fetch: (page) => nearby
            ? api.nearby(area.point, category: category, type: type, q: query, page: page)
            : api.bangalore(at: area.point, category: category, type: type, q: query, page: page),
        columns: productColumns,
        separator: 10,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemBuilder: (context, item) => ProductTile(item: item, at: area.point),
        empty: const EmptyView(icon: Icons.local_offer_outlined, title: 'No deals here yet'),
      ),
      bottomNavigationBar: const SafeArea(top: false, child: CartBar()),
    );
  }
}
