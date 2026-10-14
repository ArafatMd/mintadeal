import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'all_deals_screen.dart';
import 'area.dart';
import 'cart_button.dart';
import 'category_style.dart';
import 'promo_banners.dart';
import 'shop_card_tile.dart';

enum FeedScope { nearby, bangalore }

/// Header background behind the location, switch and search.
const _headerColor = Color(0xFFFFF8F0);

/// The home tab: location and Nearby / All Bengaluru switch, search, categories, deal banners,
/// filters, then shops with deals as cards.
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
  List<Promo> _promos = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  bool get _nearby => _scope == FeedScope.nearby;

  void _openAll() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AllDealsScreen(nearby: _nearby, category: _category, type: _type, query: _query),
      ));

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<(VendorCategory?, ListingType?)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(category: _category, type: _type),
    );
    if (result != null) {
      setState(() {
        _category = result.$1;
        _type = result.$2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final area = ref.watch(areaProvider);
    final signedIn = ref.watch(sessionProvider).value != null;
    final api = ref.watch(apiProvider);
    final theme = Theme.of(context);
    final unfiltered = _category == null && _type == null && _query.isEmpty;

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
          onFilters: _openFilters,
        ),
        Expanded(
          child: PagedList<ShopCard>(
            queryKey: (_scope, area.name, _category, _type, _query, signedIn),
            fetch: (page) async {
              final result = _nearby
                  ? await api.nearbyShops(area.point, category: _category, type: _type, q: _query, page: page)
                  : await api.bangaloreShops(at: area.point, category: _category, type: _type, q: _query, page: page);
              // Banners come from the unfiltered first page, so they always reflect real deals.
              if (page == 0 && unfiltered && mounted) setState(() => _promos = promosFrom(result.items));
              return result;
            },
            columns: (width) => width >= 900 ? 4 : (width >= 600 ? 3 : 2),
            separator: 12,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            header: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _CategoryRail(selected: _category, onSelected: (c) => setState(() => _category = c)),
              if (_promos.isNotEmpty) ...[
                const SizedBox(height: 4),
                PromoCarousel(
                  promos: _promos,
                  kicker: _nearby ? 'SAVINGS NEAR YOU' : 'ACROSS BENGALURU',
                  onView: (c) => setState(() => _category = c),
                ),
              ],
              const SizedBox(height: 14),
              _TypeRow(type: _type, onType: (t) => setState(() => _type = t), onFilters: _openFilters),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 16, 0, 10),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      [
                        if (_category != null) _category!.label,
                        _nearby ? 'Deals near ${area.name}' : 'Deals across Bengaluru',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton(
                    onPressed: _openAll,
                    style: TextButton.styleFrom(foregroundColor: theme.colorScheme.primary),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('See all', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 18),
                    ]),
                  ),
                ]),
              ),
            ]),
            itemBuilder: (context, shop) => ShopCardTile(shop: shop, at: area.point),
            empty: EmptyView(
              icon: Icons.storefront_outlined,
              title: _nearby ? 'No deals near ${area.name} yet' : 'No city-wide deals yet',
              message: _nearby
                  ? 'Try another area or switch to All Bengaluru.'
                  : 'Shops that deliver across Bengaluru and venue offers appear here.',
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
    required this.onFilters,
  });

  final FeedScope scope;
  final String areaName;
  final VoidCallback onArea;
  final ValueChanged<FeedScope> onScope;
  final ValueChanged<String> onSearch;
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final ink = theme.colorScheme.onSurface;
    final nearby = scope == FeedScope.nearby;
    final location = InkWell(
      onTap: onArea,
      borderRadius: BorderRadius.circular(8),
      child: Row(children: [
        Icon(Icons.location_on, color: theme.colorScheme.primary, size: 24),
        const SizedBox(width: 4),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(nearby ? 'NEARBY DEALS' : 'DEALS IN BENGALURU',
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: ink.withValues(alpha: 0.7), letterSpacing: 1.4, fontWeight: FontWeight.w600)),
            Row(children: [
              Flexible(
                child: Text(areaName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(color: ink, fontWeight: FontWeight.w800, fontSize: 18)),
              ),
              Icon(Icons.keyboard_arrow_down, color: ink, size: 20),
            ]),
          ]),
        ),
      ]),
    );
    return Container(
      color: light ? _headerColor : theme.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            LayoutBuilder(builder: (context, c) {
              final scopeSwitch = _ScopeSwitch(scope: scope, onChanged: onScope);
              // On narrow phones the switch moves under the location so nothing gets squeezed.
              if (c.maxWidth < 350) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [Expanded(child: location), const CartButton()]),
                  const SizedBox(height: 8),
                  Padding(padding: const EdgeInsets.only(right: 4), child: scopeSwitch),
                ]);
              }
              return Row(children: [
                Expanded(child: location),
                const SizedBox(width: 4),
                // Full size when it fits; shrinks rather than squeezing the area name away.
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: c.maxWidth * 0.48),
                  child: FittedBox(fit: BoxFit.scaleDown, child: scopeSwitch),
                ),
                const CartButton(),
              ]);
            }),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextField(
                onChanged: onSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search “atta”, “cake”, “haircut”…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Filters',
                    onPressed: onFilters,
                    icon: Icon(Icons.tune, color: theme.colorScheme.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Nearby | All Bengaluru, in a bordered pill. The selected side is red.
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
      return Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onChanged(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 4),
                Text(label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w600, fontSize: 12.5)),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        pill(FeedScope.nearby, Icons.near_me, 'Nearby'),
        pill(FeedScope.bangalore, Icons.location_city, 'All Bengaluru'),
      ]),
    );
  }
}

/// Round pastel category icons with labels; the selected one has a red label and underline.
class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.selected, required this.onSelected});

  final VendorCategory? selected;
  final ValueChanged<VendorCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final red = theme.colorScheme.primary;
    Widget tile(VendorCategory? c) {
      final isSelected = selected == c;
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onSelected(isSelected ? null : c),
        child: SizedBox(
          width: 76,
          child: Column(children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: c?.tint ?? const Color(0xFFFFE4E6), shape: BoxShape.circle),
              child: Icon(c?.icon ?? Icons.grid_view_rounded, size: 28, color: c == null ? red : MintadealColors.charcoal),
            ),
            const SizedBox(height: 6),
            Text(c?.label ?? 'All',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isSelected ? red : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                )),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: isSelected ? 36 : 0,
              decoration: BoxDecoration(color: red, borderRadius: BorderRadius.circular(2)),
            ),
          ]),
        ),
      );
    }

    return SizedBox(
      height: 112,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: 12),
        children: [tile(null), for (final c in VendorCategory.values) tile(c)],
      ),
    );
  }
}

/// All / Products / Venue offers pills, and a Filter button on the right.
class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.type, required this.onType, required this.onFilters});

  final ListingType? type;
  final ValueChanged<ListingType?> onType;
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget pill(ListingType? t, String label) {
      final selected = type == t;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: selected ? MintadealColors.yellow : theme.colorScheme.surface,
          shape: StadiumBorder(
              side: BorderSide(color: selected ? MintadealColors.yellow : theme.colorScheme.outlineVariant)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => onType(t),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Text(label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected ? MintadealColors.charcoal : theme.colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  )),
            ),
          ),
        ),
      );
    }

    return Row(children: [
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            pill(null, 'All'),
            pill(ListingType.PRODUCT, 'Products'),
            pill(ListingType.OFFER, 'Venue offers'),
          ]),
        ),
      ),
      OutlinedButton.icon(
        onPressed: onFilters,
        icon: const Icon(Icons.tune, size: 18),
        label: const Text('Filter'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          foregroundColor: theme.colorScheme.onSurface,
          side: BorderSide(color: theme.colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ]);
  }
}

/// Category and deal type in one sheet.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.category, required this.type});

  final VendorCategory? category;
  final ListingType? type;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late VendorCategory? _category = widget.category;
  late ListingType? _type = widget.type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Filters', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Text('Show', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (t, label) in [(null, 'All'), (ListingType.PRODUCT, 'Products'), (ListingType.OFFER, 'Venue offers')])
              ChoiceChip(
                showCheckmark: false,
                label: Text(label),
                selected: _type == t,
                onSelected: (_) => setState(() => _type = t),
              ),
          ]),
          const SizedBox(height: 16),
          Text('Category', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(
              showCheckmark: false,
              label: const Text('All'),
              selected: _category == null,
              onSelected: (_) => setState(() => _category = null),
            ),
            for (final c in VendorCategory.values)
              ChoiceChip(
                showCheckmark: false,
                avatar: Icon(c.icon, size: 18),
                label: Text(c.label),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
              ),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, (null, null)),
                child: const Text('Clear'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context, (_category, _type)),
                child: const Text('Show deals'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
