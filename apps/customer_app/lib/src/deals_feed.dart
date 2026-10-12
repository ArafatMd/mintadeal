import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'area.dart';
import 'cart_button.dart';
import 'listing_card.dart';

enum FeedScope { nearby, bangalore }

/// Nearby deals or Deals in Bangalore, with search, category and type filters.
class DealsFeed extends ConsumerStatefulWidget {
  const DealsFeed({super.key, required this.scope});

  final FeedScope scope;

  @override
  ConsumerState<DealsFeed> createState() => _DealsFeedState();
}

class _DealsFeedState extends ConsumerState<DealsFeed> {
  VendorCategory? _category;
  ListingType? _type;
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final area = ref.watch(areaProvider);
    final signedIn = ref.watch(sessionProvider).value != null;
    final api = ref.watch(apiProvider);
    final nearby = widget.scope == FeedScope.nearby;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: InkWell(
          onTap: () => pickArea(context, ref),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nearby ? 'Nearby deals' : 'Deals in Bangalore',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.place_outlined, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 2),
                  Text(area.name, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
                  Icon(Icons.expand_more, size: 18, color: theme.colorScheme.primary),
                ]),
              ],
            ),
          ),
        ),
        toolbarHeight: 72,
        actions: const [CartButton(), SizedBox(width: 8)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SearchBar(
              hintText: nearby ? 'Search shops and items near you' : 'Search city-wide deals',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (text) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = text.trim()));
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final t in [null, ...ListingType.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t == null ? 'All' : (t == ListingType.PRODUCT ? 'Products' : 'Venue offers')),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    ),
                  ),
                const VerticalDivider(width: 16, indent: 8, endIndent: 8),
                for (final c in VendorCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(c.icon, size: 18),
                      label: Text(c.label),
                      selected: _category == c,
                      onSelected: (on) => setState(() => _category = on ? c : null),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PagedList<DiscoveryItem>(
              queryKey: (area.name, _category, _type, _query, signedIn),
              fetch: (page) => nearby
                  ? api.nearby(area.point, category: _category, type: _type, q: _query, page: page)
                  : api.bangalore(at: area.point, category: _category, type: _type, q: _query, page: page),
              itemBuilder: (context, item) => ListingCard(item: item, at: area.point),
              empty: EmptyView(
                icon: Icons.storefront_outlined,
                title: nearby ? 'No deals near ${area.name} yet' : 'No city-wide deals yet',
                message: nearby
                    ? 'Try another area or check Deals in Bangalore.'
                    : 'Shops that deliver across Bangalore and venue offers appear here.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
