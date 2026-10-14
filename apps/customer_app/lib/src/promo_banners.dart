import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

/// One slide in the home carousel: an admin banner with its photo, or one made from real discounts.
class Slide {
  const Slide({required this.title, this.kicker, this.subtitle, this.imageUrl, this.icon, this.onTap});

  final String title;
  final String? kicker;
  final String? subtitle;

  /// The admin's photo; generated slides show [icon] on red instead.
  final String? imageUrl;
  final IconData? icon;

  /// Null hides the View Deals button.
  final VoidCallback? onTap;
}

/// Slides from real deals: the categories with the biggest discounts first, up to four.
/// With no discounts at all there is one welcome slide.
List<Slide> slidesFromShops(List<ShopCard> shops, {required String kicker, required ValueChanged<VendorCategory?> onView}) {
  final best = <VendorCategory, int>{};
  for (final s in shops) {
    final p = s.bestDiscountPercent;
    if (p == null) continue;
    final c = s.vendor.category;
    if (p > (best[c] ?? 0)) best[c] = p;
  }
  final sorted = best.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  if (sorted.isEmpty) {
    return [
      Slide(
        kicker: kicker,
        title: 'Local deals',
        subtitle: 'From shops in your neighbourhood',
        icon: Icons.storefront_outlined,
        onTap: () => onView(null),
      ),
    ];
  }
  return [
    for (final e in sorted.take(4))
      Slide(
        kicker: kicker,
        title: 'Up to ${e.value}% Off',
        subtitle: 'On ${e.key.label}',
        icon: e.key.icon,
        onTap: () => onView(e.key),
      ),
  ];
}

/// A sliding row of banners with a yellow "View Deals" button and page dots.
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key, required this.slides});

  final List<Slide> slides;

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
      if (!_controller.hasClients || widget.slides.length < 2) return;
      _controller.animateToPage((_page + 1) % widget.slides.length,
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
            children: [for (final s in widget.slides) _SlideView(slide: s)],
          ),
          if (widget.slides.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < widget.slides.length; i++)
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

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final Slide slide;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = slide;
    final photo = s.imageUrl != null;
    return GestureDetector(
      onTap: s.onTap,
      child: Stack(fit: StackFit.expand, children: [
        // Red background, then the admin's photo on top of it.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF8E0010), Color(0xFFC4000F), MintadealColors.red]),
          ),
        ),
        if (photo)
          Image.network(s.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
        else
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
                    child: Icon(s.icon ?? Icons.storefront_outlined, size: 52, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        // A dark red fade on the left keeps the text readable on any photo.
        if (photo)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF8E0010).withValues(alpha: 0.95),
                const Color(0xFFB0000E).withValues(alpha: 0.75),
                Colors.transparent,
              ], stops: const [0, 0.45, 0.8]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 120, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (s.kicker != null)
              Text(s.kicker!.toUpperCase(),
                  maxLines: 1,
                  style: text.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9), letterSpacing: 2.2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(s.title, style: text.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
            if (s.subtitle != null)
              Text(s.subtitle!,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium?.copyWith(color: Colors.white)),
            if (s.onTap != null) ...[
              const SizedBox(height: 8),
              Material(
                color: MintadealColors.yellow,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: s.onTap,
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
            ],
          ]),
        ),
      ]),
    );
  }
}
