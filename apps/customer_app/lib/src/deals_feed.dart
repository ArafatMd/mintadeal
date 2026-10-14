import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'area.dart';
import 'cart_button.dart';
import 'product_tile.dart';

enum FeedScope { nearby, bangalore }

/// The home tab: a yellow header with the area, a Nearby / All Bangalore switch and search,
/// then categories and a grid of deals.
class DealsFeed extends ConsumerStatefulWidget {
  const DealsFeed({super.key});

  @override
  ConsumerState<DealsFeed> createState() => _DealsFeedState();
}

class _DealsFeedState extends ConsumerState<DealsFeed> {
  FeedScope _scope = FeedScope.nearby;
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
    final nearby = _scope == FeedScope.nearby;
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(children: [
        _Header(
          scope: _scope,
          areaName: area.name,
          onArea: () => pickArea(context, ref),
          onScope: (s) => setState(() => _scope = s),
          onSearch: (text) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = text.trim()));
          },
        ),
        Expanded(
          child: PagedList<DiscoveryItem>(
            queryKey: (_scope, area.name, _category, _type, _query, signedIn),
            fetch: (page) => nearby
                ? api.nearby(area.point, category: _category, type: _type, q: _query, page: page)
                : api.bangalore(at: area.point, category: _category, type: _type, q: _query, page: page),
            columns: productColumns,
            separator: 10,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            header: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _CategoryRail(selected: _category, onSelected: (c) => setState(() => _category = c)),
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final t in [null, ...ListingType.values])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        label: Text(t == null ? 'All' : (t == ListingType.PRODUCT ? 'Products' : 'Venue offers')),
                        selected: _type == t,
                        onSelected: (_) => setState(() => _type = t),
                      ),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
                child: Text(
                  [
                    if (_category != null) _category!.label,
                    nearby ? 'Deals near ${area.name}' : 'Deals across Bangalore',
                  ].join(' · '),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ]),
            itemBuilder: (context, item) => ProductTile(item: item, at: area.point),
            empty: EmptyView(
              icon: Icons.storefront_outlined,
              title: nearby ? 'No deals near ${area.name} yet' : 'No city-wide deals yet',
              message: nearby
                  ? 'Try another area or switch to All Bangalore.'
                  : 'Shops that deliver across Bangalore and venue offers appear here.',
            ),
          ),
        ),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.scope,
    required this.areaName,
    required this.onArea,
    required this.onScope,
    required this.onSearch,
  });

  final FeedScope scope;
  final String areaName;
  final VoidCallback onArea;
  final ValueChanged<FeedScope> onScope;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final ink = light ? MintadealColors.charcoal : theme.colorScheme.onSecondaryContainer;
    final nearby = scope == FeedScope.nearby;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: light
              ? const [MintadealColors.yellow, Color(0xFFF7DE8E)]
              : [theme.colorScheme.secondaryContainer, theme.colorScheme.surfaceContainerLowest],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: onArea,
                  borderRadius: BorderRadius.circular(8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nearby ? 'Nearby deals' : 'Deals in Bangalore',
                        style: theme.textTheme.labelLarge?.copyWith(color: ink, fontWeight: FontWeight.w800)),
                    Row(children: [
                      Flexible(
                        child: Text(areaName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(color: ink, fontWeight: FontWeight.w900)),
                      ),
                      Icon(Icons.keyboard_arrow_down, color: ink),
                    ]),
                    Text(nearby ? 'Local shops around you' : 'City-wide delivery and venue offers',
                        style: theme.textTheme.bodySmall?.copyWith(color: ink.withValues(alpha: 0.75))),
                  ]),
                ),
              ),
              Container(
                decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle),
                child: const CartButton(),
              ),
              const SizedBox(width: 8),
            ]),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _ScopeSwitch(scope: scope, onChanged: onScope),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextField(
                onChanged: onSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: nearby ? 'Search "atta", "cake", "haircut"' : 'Search city-wide deals',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Two pills: Nearby and All Bangalore. The selected one is red.
class _ScopeSwitch extends StatelessWidget {
  const _ScopeSwitch({required this.scope, required this.onChanged});

  final FeedScope scope;
  final ValueChanged<FeedScope> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget pill(FeedScope s, IconData icon, String label) {
      final selected = scope == s;
      final fg = selected ? scheme.onPrimary : scheme.onSurface;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onChanged(s),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(13)),
      child: Row(children: [
        pill(FeedScope.nearby, Icons.near_me, 'Nearby'),
        pill(FeedScope.bangalore, Icons.location_city, 'All Bangalore'),
      ]),
    );
  }
}

/// Square category tiles with a label underneath, scrolling sideways. "All" clears the filter.
class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.selected, required this.onSelected});

  final VendorCategory? selected;
  final ValueChanged<VendorCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget tile(VendorCategory? c) {
      final isSelected = selected == c;
      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onSelected(isSelected ? null : c),
          child: SizedBox(
            width: 70,
            child: Column(children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isSelected ? scheme.secondaryContainer : scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSelected ? scheme.primary : Colors.transparent, width: 2),
                ),
                child: Icon(c?.icon ?? Icons.apps, size: 30, color: isSelected ? scheme.primary : scheme.onTertiaryContainer),
              ),
              const SizedBox(height: 4),
              Text(c?.label ?? 'All',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? scheme.primary : scheme.onSurface,
                  )),
            ]),
          ),
        ),
      );
    }

    return SizedBox(
      height: 114,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: 12),
        children: [tile(null), for (final c in VendorCategory.values) tile(c)],
      ),
    );
  }
}
