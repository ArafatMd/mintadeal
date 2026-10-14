import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

final orderReviewProvider =
    FutureProvider.autoDispose.family<OrderReview, String>((ref, orderId) => ref.watch(apiProvider).orderReview(orderId));

/// On a completed order: rate it, or see (and change) the rating already given, with the shop's reply.
class RateOrderCard extends ConsumerStatefulWidget {
  const RateOrderCard({super.key, required this.orderId, required this.shopName});

  final String orderId;
  final String shopName;

  @override
  ConsumerState<RateOrderCard> createState() => _RateOrderCardState();
}

class _RateOrderCardState extends ConsumerState<RateOrderCard> {
  int _stars = 0;
  final _comment = TextEditingController();
  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).rateOrder(widget.orderId, _stars, _comment.text.trim().isEmpty ? null : _comment.text.trim());
      ref.invalidate(orderReviewProvider(widget.orderId));
      if (mounted) {
        setState(() => _editing = false);
        showMessage(context, 'Thanks for rating ${widget.shopName}!');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(orderReviewProvider(widget.orderId)).value;
    if (value == null) return const SizedBox.shrink();
    final review = value.review;
    if (!value.canReview && review == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    if (review != null && !_editing) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          child: ReviewTile(
            review: review,
            trailing: value.canReview
                ? TextButton(
                    onPressed: () => setState(() {
                      _editing = true;
                      _stars = review.rating;
                      _comment.text = review.comment ?? '';
                    }),
                    child: const Text('Edit'),
                  )
                : null,
          ),
        ),
      );
    }

    return Card(
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How was ${widget.shopName}?', style: theme.textTheme.titleMedium),
          Text('Your rating helps neighbours choose, and helps the shop improve.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Center(child: StarPicker(value: _stars, onChanged: (v) => setState(() => _stars = v))),
          if (_stars > 0) ...[
            Center(child: Text(StarPicker.labels[_stars], style: theme.textTheme.labelLarge)),
            const SizedBox(height: 8),
            // Its own semantics node, so screen readers announce just the field's label, not the card's text.
            Semantics(
              container: true,
              child: TextField(
                controller: _comment,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Tell others about it (optional)'),
              ),
            ),
            const SizedBox(height: 4),
            Row(children: [
              if (_editing)
                TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel')),
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit rating'),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// Every visible review of a shop.
class ShopReviewsScreen extends ConsumerWidget {
  const ShopReviewsScreen({super.key, required this.vendorId, required this.shopName, this.rating, this.count = 0});

  final String vendorId;
  final String shopName;
  final double? rating;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Reviews of $shopName')),
      body: PagedList<Review>(
        queryKey: vendorId,
        fetch: (page) => api.shopReviews(vendorId, page: page),
        separator: 0,
        header: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RatingBadge(rating: rating, count: count),
        ),
        empty: const EmptyView(icon: Icons.star_outline_rounded, title: 'No reviews yet'),
        itemBuilder: (context, r) => Column(children: [ReviewTile(review: r), const Divider(height: 1)]),
      ),
    );
  }
}
