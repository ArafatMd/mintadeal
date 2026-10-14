import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/stage6.dart';
import '../util/money.dart';

/// Gold for stars: the one place a colour other than the brand is used, as everyone reads it as "rating".
const starGold = Color(0xFFF2B01E);

/// Five stars filled to [rating] (halves shown as half stars).
class Stars extends StatelessWidget {
  const Stars({super.key, required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${rating.toStringAsFixed(1)} out of 5 stars',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i ? Icons.star_rounded : (rating >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
            size: size,
            color: starGold,
          ),
      ]),
    );
  }
}

/// "★ 4.5 (120)", or nothing useful when there are no ratings yet.
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating, required this.count, this.compact = false});

  final double? rating;
  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (rating == null || count == 0) {
      return Text('No ratings yet', style: text.labelSmall?.copyWith(color: muted));
    }
    return Semantics(
      label: '${rating!.toStringAsFixed(1)} stars from $count ${count == 1 ? 'rating' : 'ratings'}',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.star_rounded, size: compact ? 16 : 18, color: starGold),
        const SizedBox(width: 3),
        Text(rating!.toStringAsFixed(1), style: (compact ? text.labelLarge : text.titleSmall)?.copyWith(fontWeight: FontWeight.w800)),
        Text(' ($count)', style: text.labelMedium?.copyWith(color: muted)),
      ]),
    );
  }
}

/// Tap a star to choose 1 to 5.
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged, this.size = 40});

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  static const labels = ['', 'Poor', 'Not great', 'Okay', 'Good', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        IconButton(
          tooltip: '$i ${i == 1 ? 'star' : 'stars'}: ${labels[i]}',
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(i),
          icon: Icon(i <= value ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: starGold),
        ),
    ]);
  }
}

/// One review: stars, name, date, comment and the shop's reply.
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review, this.trailing});

  final Review review;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Stars(rating: review.rating.toDouble()),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [review.customerName, DateFormat('d MMM yyyy').format(review.createdAt)].join(' · '),
              style: theme.textTheme.labelMedium?.copyWith(color: muted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ]),
        if (review.comment != null) ...[const SizedBox(height: 4), Text(review.comment!)],
        if (review.reply != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Reply from the shop', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(review.reply!),
            ]),
          ),
      ]),
    );
  }
}

/// A headline number with a label, for dashboards.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.hint, this.icon, this.alert = false});

  final String label;
  final String value;
  final String? hint;
  final IconData? icon;

  /// Draws attention: something needs doing.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: alert ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: alert ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: alert ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  )),
            ),
          ]),
          const SizedBox(height: 6),
          Text(value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: alert ? scheme.onPrimaryContainer : scheme.onSurface,
              )),
          if (hint != null)
            Text(hint!, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

/// Orders per day as bars, one per day, with each day's numbers in a tooltip.
///
/// A single series, so no legend: the [title] names it.
class DailyBars extends StatelessWidget {
  const DailyBars({super.key, required this.title, required this.days, this.showValue = true, this.height = 150});

  final String title;
  final List<DayStat> days;
  final bool showValue;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxOrders = days.fold(0, (m, d) => d.orders > m ? d.orders : m);
    final many = days.length > 14;
    final dayLabel = DateFormat('EEE');
    final short = DateFormat('d MMM');
    final full = DateFormat('EEE d MMM');
    final total = days.fold(0, (s, d) => s + d.orders);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            Text('$total ${total == 1 ? 'order' : 'orders'}',
                style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: height,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final d in days)
                Expanded(
                  child: Tooltip(
                    message: '${full.format(d.date)}\n${d.orders} ${d.orders == 1 ? 'order' : 'orders'}'
                        '${showValue ? ' · ${formatInr(d.valueMinor)}' : ''}',
                    child: Semantics(
                      label: '${full.format(d.date)}: ${d.orders} orders',
                      excludeSemantics: true,
                      child: Padding(
                        // A 2px gap between bars.
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                          if (!many && d.orders > 0)
                            Text('${d.orders}',
                                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 2),
                          Container(
                            height: maxOrders == 0 ? 2 : ((height - (many ? 20 : 40)) * d.orders / maxOrders).clamp(2, height - (many ? 20 : 40)),
                            constraints: const BoxConstraints(maxWidth: 28),
                            decoration: BoxDecoration(
                              color: d.orders == 0 ? scheme.outlineVariant : scheme.primary,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                          if (!many) ...[
                            const SizedBox(height: 4),
                            Text(dayLabel.format(d.date),
                                maxLines: 1,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 10,
                                )),
                          ],
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          // Bars are too narrow for a label each over a month: show the first, middle and last day instead.
          if (many && days.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (final d in [days.first, days[days.length ~/ 2], days.last])
                Text(short.format(d.date),
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 10)),
            ]),
          ],
        ]),
      ),
    );
  }
}
