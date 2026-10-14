import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

final _statsProvider = FutureProvider.autoDispose.family<VendorStats, int>((ref, days) => ref.watch(apiProvider).vendorStats(days));

/// How the shop is doing: orders, how quickly it accepts, sales, rating and best sellers.
class PerformanceScreen extends ConsumerStatefulWidget {
  const PerformanceScreen({super.key});

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(_statsProvider(_days));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Performance')),
      body: AsyncView(
        value: stats,
        onRetry: () => ref.invalidate(_statsProvider(_days)),
        data: (s) => RefreshIndicator(
          onRefresh: () => ref.refresh(_statsProvider(_days).future),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 days')),
                ButtonSegment(value: 30, label: Text('30 days')),
                ButtonSegment(value: 90, label: Text('90 days')),
              ],
              selected: {_days},
              onSelectionChanged: (v) => setState(() => _days = v.first),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.55,
              children: [
                StatTile(label: 'Sales', value: formatInr(s.salesMinor), hint: '${s.completed} completed orders',
                    icon: Icons.payments_outlined),
                StatTile(label: 'Orders', value: '${s.orders}', hint: 'Average ${formatInr(s.avgOrderMinor)}',
                    icon: Icons.receipt_long_outlined),
                StatTile(
                  label: 'Accepted',
                  value: '${(s.acceptanceRate * 100).round()}%',
                  hint: s.missed > 0 ? '${s.missed} missed in time' : 'None missed',
                  icon: Icons.check_circle_outline,
                  alert: s.missed > 0 || (s.orders > 0 && s.acceptanceRate < 0.8),
                ),
                StatTile(
                  label: 'Time to accept',
                  value: s.avgAcceptMinutes == null ? '–' : '${s.avgAcceptMinutes!.toStringAsFixed(s.avgAcceptMinutes! < 10 ? 1 : 0)} min',
                  hint: 'You have 15 minutes',
                  icon: Icons.timer_outlined,
                ),
              ],
            ),
            const SizedBox(height: 10),
            DailyBars(title: 'Orders per day', days: s.daily),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.star_rounded, color: starGold),
                title: RatingBadge(rating: s.rating, count: s.ratingCount),
                subtitle: Text('${s.followers} ${s.followers == 1 ? 'person follows' : 'people follow'} your shop'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShopReviewsTab())),
              ),
            ),
            const SizedBox(height: 16),
            Text('Best sellers', style: theme.textTheme.titleMedium),
            if (s.topItems.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No orders in this period yet.')),
            for (final (i, t) in s.topItems.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
                title: Text(t.title),
                subtitle: Text('${t.quantity} sold'),
                trailing: Text(formatInr(t.valueMinor)),
              ),
            if (s.cancelledByShop > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('You declined ${s.cancelledByShop} ${s.cancelledByShop == 1 ? 'order' : 'orders'} in this period. '
                    'Keep stock up to date so customers can order with confidence.', style: theme.textTheme.bodySmall),
              ),
          ]),
        ),
      ),
    );
  }
}

/// The shop's reviews, with a reply box on each.
class ShopReviewsTab extends ConsumerStatefulWidget {
  const ShopReviewsTab({super.key});

  @override
  ConsumerState<ShopReviewsTab> createState() => _ShopReviewsTabState();
}

class _ShopReviewsTabState extends ConsumerState<ShopReviewsTab> {
  int _reload = 0;

  Future<void> _reply(Review r) async {
    final controller = TextEditingController(text: r.reply);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reply to this review'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 500,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Thank the customer, or explain what you will do'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Post reply')),
        ],
      ),
    );
    if (text == null) return;
    try {
      await ref.read(apiProvider).replyToReview(r.id, text.isEmpty ? null : text);
      setState(() => _reload++);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: PagedList<Review>(
        queryKey: _reload,
        fetch: (page) => api.myShopReviews(page: page),
        separator: 0,
        header: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('Customers see your replies under their review.', style: Theme.of(context).textTheme.bodySmall),
        ),
        empty: const EmptyView(
          icon: Icons.star_outline_rounded,
          title: 'No reviews yet',
          message: 'Customers can rate an order once it is completed.',
        ),
        itemBuilder: (context, r) => Column(children: [
          ReviewTile(
            review: r,
            trailing: TextButton(onPressed: () => _reply(r), child: Text(r.reply == null ? 'Reply' : 'Edit reply')),
          ),
          const Divider(height: 1),
        ]),
      ),
    );
  }
}
