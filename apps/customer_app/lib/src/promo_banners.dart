import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

/// One banner: the best discount in a category, worked out from the shops on the home screen.
class Promo {
  const Promo({required this.category, required this.percent});

  final VendorCategory? category;
  final int? percent;
}

/// Builds banners from real deals: the categories with the biggest discounts first, up to four.
/// With no discounts at all there is one welcome banner.
List<Promo> promosFrom(List<ShopCard> shops) {
  final best = <VendorCategory, int>{};
  for (final s in shops) {
    final p = s.bestDiscountPercent;
    if (p == null) continue;
    final c = s.vendor.category;
    if (p > (best[c] ?? 0)) best[c] = p;
  }
  final sorted = best.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  if (sorted.isEmpty) return const [Promo(category: null, percent: null)];
  return [for (final e in sorted.take(4)) Promo(category: e.key, percent: e.value)];
}

/// A sliding row of dark red banners with a yellow "View Deals" button and page dots.
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key, required this.promos, required this.kicker, required this.onView});

  final List<Promo> promos;

  /// The small spaced-out line above the headline, e.g. "SAVINGS NEAR YOU".
  final String kicker;
  final ValueChanged<VendorCategory?> onView;

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  final _controller = PageController();
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients || widget.promos.length < 2) return;
      _controller.animateToPage((_page + 1) % widget.promos.length,
          duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(children: [
          PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              for (final p in widget.promos)
                _Banner(promo: p, kicker: widget.kicker, onView: () => widget.onView(p.category)),
            ],
          ),
          if (widget.promos.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < widget.promos.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: i == _page ? 1 : 0.45),
                    ),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.promo, required this.kicker, required this.onView});

  final Promo promo;
  final String kicker;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = promo.category;
    final headline = promo.percent == null ? 'Local deals' : 'Up to ${promo.percent}% Off';
    final sub = c == null ? 'From shops in your neighbourhood' : 'On ${c.label}';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF8E0010), Color(0xFFC4000F), MintadealColors.red],
        ),
      ),
      child: Stack(children: [
        // Artwork: the category's icon on soft circles, on the right.
        Positioned(
          right: -30,
          top: -20,
          bottom: -20,
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)),
              child: Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.16)),
                  child: Icon(c?.icon ?? Icons.storefront_outlined, size: 52, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 120, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(kicker,
                maxLines: 1,
                style: text.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9), letterSpacing: 2.2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(headline,
                  style: text.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
            Text(sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Material(
              color: MintadealColors.yellow,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onView,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('View Deals',
                        style: text.labelLarge?.copyWith(color: MintadealColors.charcoal, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward, size: 16, color: MintadealColors.charcoal),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
