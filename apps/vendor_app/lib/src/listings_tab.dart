import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'listing_form_screen.dart';
import 'providers.dart';

class ListingsTab extends ConsumerWidget {
  const ListingsTab({super.key, required this.shop});

  final Vendor shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(myListingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(shop.displayName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context, null),
        icon: const Icon(Icons.add),
        label: const Text('New listing'),
      ),
      body: AsyncView(
        value: listings,
        onRetry: () => ref.invalidate(myListingsProvider),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(myListingsProvider.future),
          child: items.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 80),
                  EmptyView(
                    icon: Icons.sell_outlined,
                    title: 'Post your first deal',
                    message: 'Add a product with a photo and price, or a venue offer. It takes under a minute.',
                  ),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _ListingTile(listing: items[i], onTap: () => _open(context, items[i])),
                ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Listing? listing) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListingFormScreen(shop: shop, existing: listing)));
  }
}

class _ListingTile extends ConsumerStatefulWidget {
  const _ListingTile({required this.listing, required this.onTap});

  final Listing listing;
  final VoidCallback onTap;

  @override
  ConsumerState<_ListingTile> createState() => _ListingTileState();
}

class _ListingTileState extends ConsumerState<_ListingTile> {
  bool _busy = false;

  Future<void> _act(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(myListingsProvider);
      if (mounted) showMessage(context, done);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editStock() async {
    final controller = TextEditingController(text: widget.listing.stock?.toString() ?? '');
    final result = await showDialog<(bool, int?)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stock'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Units in stock', helperText: 'Leave empty if you do not count stock'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, (true, int.tryParse(controller.text.trim()))),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await _act(() => ref.read(apiProvider).updateStock(widget.listing.id, result.$2), 'Stock updated');
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    final api = ref.read(apiProvider);
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: l.status == ListingStatus.REMOVED ? null : widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CatalogueImage(url: l.imageUrl, category: l.category, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  PriceTag(priceMinor: l.priceMinor, offerPriceMinor: l.offerPriceMinor),
                  const SizedBox(height: 4),
                  Text(
                    [
                      l.listingType.label,
                      if (l.listingType == ListingType.PRODUCT) l.stock == null ? 'Stock not tracked' : '${l.stock} in stock',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                ]),
              ),
              StatusChip(label: l.status.label, color: listingStatusColor(l.status)),
            ]),
            if (l.status == ListingStatus.REMOVED && l.removedReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Removed: ${l.removedReason}', style: TextStyle(color: theme.colorScheme.error)),
              ),
            if (l.status != ListingStatus.REMOVED)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 8, children: [
                  if (l.status != ListingStatus.ACTIVE)
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : () => _act(() => api.publishListing(l.id), 'Live for customers'),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Publish'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _act(() => api.pauseListing(l.id), 'Paused'),
                      icon: const Icon(Icons.pause),
                      label: const Text('Pause'),
                    ),
                  if (l.listingType == ListingType.PRODUCT)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _editStock,
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Stock'),
                    ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}
