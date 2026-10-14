import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'area.dart';
import 'product_tile.dart';
import 'providers.dart';
import 'sign_in.dart';
import 'storefront_screen.dart';

/// Shops the customer follows and the latest deals from them.
class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(sessionProvider).value != null;
    final area = ref.watch(areaProvider);
    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Following')),
        body: EmptyView(
          icon: Icons.favorite_border,
          title: 'Follow the shops you like',
          message: 'Their new deals show up here first.',
          action: FilledButton(onPressed: () => ensureSignedIn(context, ref), child: const Text('Sign in')),
        ),
      );
    }
    final follows = ref.watch(followsProvider);
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: AsyncView(
        value: follows,
        onRetry: () => ref.invalidate(followsProvider),
        data: (shops) => shops.isEmpty
            ? const EmptyView(
                icon: Icons.favorite_border,
                title: 'You are not following any shops yet',
                message: 'Open a shop and tap Follow.',
              )
            : PagedList<DiscoveryItem>(
                queryKey: (area.name, shops.length),
                header: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: shops.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => _ShopBubble(shop: shops[i], at: area.point),
                    ),
                  ),
                ),
                fetch: (page) => api.nearby(area.point, followedOnly: true, page: page),
                columns: productColumns,
                separator: 10,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemBuilder: (context, item) => ProductTile(item: item, at: area.point),
                empty: EmptyView(
                  icon: Icons.local_offer_outlined,
                  title: 'No deals from your shops near ${area.name}',
                ),
              ),
      ),
    );
  }
}

class _ShopBubble extends StatelessWidget {
  const _ShopBubble({required this.shop, required this.at});

  final VendorPublic shop;
  final GeoPoint at;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => StorefrontScreen(vendorId: shop.id, at: at),
      )),
      child: SizedBox(
        width: 76,
        child: Column(children: [
          CatalogueImage(url: shop.logoUrl, category: shop.category, size: 60, radius: 30),
          const SizedBox(height: 6),
          Text(shop.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall),
        ]),
      ),
    );
  }
}
