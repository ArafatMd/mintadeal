import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'dialogs.dart';

/// Moderation: review what shops publish and take down misleading or prohibited listings.
class ListingsPage extends ConsumerStatefulWidget {
  const ListingsPage({super.key});

  @override
  ConsumerState<ListingsPage> createState() => _ListingsPageState();
}

class _ListingsPageState extends ConsumerState<ListingsPage> {
  ListingStatus? _status = ListingStatus.ACTIVE;
  int _reload = 0;

  Future<void> _remove(Listing l) async {
    final reason = await askReason(context, title: 'Remove "${l.title}"', action: 'Remove');
    if (reason == null) return;
    try {
      await ref.read(apiProvider).removeListing(l.id, reason);
      setState(() => _reload++);
      if (mounted) showMessage(context, 'Listing removed');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final date = DateFormat('d MMM, h:mm a');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Listings', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(width: 16),
          for (final s in [...ListingStatus.values, null])
            ChoiceChip(
              label: Text(s == null ? 'All' : s.label),
              selected: _status == s,
              onSelected: (_) => setState(() => _status = s),
            ),
          IconButton(tooltip: 'Refresh', onPressed: () => setState(() => _reload++), icon: const Icon(Icons.refresh)),
        ]),
      ),
      Expanded(
        child: PagedList<(Listing, String?)>(
          queryKey: (_status, _reload),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          separator: 8,
          fetch: (page) => api.adminListings(status: _status, page: page),
          empty: const EmptyView(icon: Icons.sell_outlined, title: 'No listings'),
          itemBuilder: (context, row) {
            final (l, vendorName) = row;
            return Card(
              child: ListTile(
                leading: CatalogueImage(url: l.imageUrl, category: l.category, size: 48),
                title: Text(l.title),
                subtitle: Text([
                  vendorName ?? 'Unknown shop',
                  l.listingType.label,
                  if (l.discountPercent != null)
                    '${formatInr(l.effectivePriceMinor)} (was ${formatInr(l.priceMinor)}, ${l.discountPercent}% off)'
                  else
                    formatInr(l.priceMinor),
                  'updated ${date.format(l.updatedAt)}',
                  if (l.removedReason != null) 'removed: ${l.removedReason}',
                ].join(' · ')),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  StatusChip(label: l.status.label, color: listingStatusColor(l.status)),
                  if (l.status != ListingStatus.REMOVED)
                    IconButton(
                      tooltip: 'Remove listing',
                      onPressed: () => _remove(l),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
