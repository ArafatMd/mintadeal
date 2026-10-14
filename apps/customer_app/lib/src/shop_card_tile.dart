import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'category_style.dart';
import 'providers.dart';
import 'sign_in.dart';
import 'storefront_screen.dart';

/// A shop on the home screen: cover photo with its best discount and a follow heart,
/// then logo, name, tagline, distance, how many deals and a tag.
class ShopCardTile extends ConsumerStatefulWidget {
  const ShopCardTile({super.key, required this.shop, this.at});

  final ShopCard shop;
  final GeoPoint? at;

  @override
  ConsumerState<ShopCardTile> createState() => _ShopCardTileState();
}

class _ShopCardTileState extends ConsumerState<ShopCardTile> {
  // Follow state changes here at once; the next feed load confirms it.
  late bool _followed = widget.shop.followed;

  @override
  void didUpdateWidget(covariant ShopCardTile old) {
    super.didUpdateWidget(old);
    if (old.shop != widget.shop) _followed = widget.shop.followed;
  }

  Future<void> _toggleFollow() async {
    if (!await ensureSignedIn(context, ref)) return;
    final api = ref.read(apiProvider);
    final next = !_followed;
    setState(() => _followed = next);
    try {
      next ? await api.follow(widget.shop.vendor.id) : await api.unfollow(widget.shop.vendor.id);
      ref.invalidate(followsProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _followed = !next);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final v = shop.vendor;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final (tagBg, tagFg) = shopTagColors(shop.tag);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 1.5,
      shadowColor: Colors.black26,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => StorefrontScreen(vendorId: v.id, at: widget.at),
        )),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 16 / 8,
            child: Stack(fit: StackFit.expand, children: [
              _Cover(url: shop.coverImageUrl, category: v.category),
              if (shop.bestDiscountPercent != null)
                Positioned(top: 10, left: 10, child: _OffBadge(percent: shop.bestDiscountPercent!)),
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  tooltip: _followed ? 'Unfollow ${v.displayName}' : 'Follow ${v.displayName}',
                  onPressed: _toggleFollow,
                  icon: Icon(
                    _followed ? Icons.favorite : Icons.favorite_border,
                    color: _followed ? MintadealColors.red : Colors.white,
                    shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Avatar(url: v.logoUrl, category: v.category),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(v.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text(shop.tagline ?? v.category.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.location_on_outlined, size: 13, color: muted),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          [v.area, ?shop.distanceText].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(color: muted),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                if (shop.ratingCount > 0)
                  RatingBadge(rating: shop.rating, count: shop.ratingCount, compact: true)
                else ...[
                  const Icon(Icons.local_offer, size: 15, color: starGold),
                  const SizedBox(width: 4),
                  Text('${shop.dealCount}',
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                  Text(shop.dealCount == 1 ? ' deal' : ' deals',
                      style: theme.textTheme.labelMedium?.copyWith(color: muted)),
                ],
                const Spacer(),
                Flexible(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(20)),
                    child: Text(shop.tag.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(color: tagFg, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.category});

  final String? url;
  final VendorCategory category;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: category.tint,
      child: Icon(category.icon, size: 44, color: category.accent.withValues(alpha: 0.55)),
    );
    if (url == null) return placeholder;
    return Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.category});

  final String? url;
  final VendorCategory category;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: 20,
      backgroundColor: category.accent,
      child: Icon(category.icon, size: 20, color: Colors.white),
    );
    if (url == null) return fallback;
    return ClipOval(
      child: Image.network(url!, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
    );
  }
}

/// "20% OFF": red for big discounts, green for medium, yellow for small.
class _OffBadge extends StatelessWidget {
  const _OffBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = percent >= 25
        ? (MintadealColors.red, Colors.white)
        : percent >= 15
            ? (const Color(0xFF1E9E55), Colors.white)
            : (MintadealColors.yellow, MintadealColors.charcoal);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text('$percent% OFF',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w800)),
    );
  }
}
