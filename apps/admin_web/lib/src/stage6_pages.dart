import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'dialogs.dart';

final _overviewProvider = FutureProvider.autoDispose((ref) => ref.watch(apiProvider).adminOverview());

/// The admin home: today's numbers, the last 7 days, and anything that needs someone to act.
class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key, required this.onOpen});

  /// Opens another admin page by its menu label, e.g. "Support".
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(_overviewProvider);
    final theme = Theme.of(context);
    return AsyncView(
      value: overview,
      onRetry: () => ref.invalidate(_overviewProvider),
      data: (o) {
        final attention = [
          (o.openTickets, 'Help requests waiting', Icons.support_agent_outlined, 'Support'),
          (o.shopsWaitingForReview, 'Shops waiting for review', Icons.storefront_outlined, 'Vendors'),
          (o.ordersWaitingForShop, 'Orders waiting for a shop', Icons.hourglass_top, 'Orders'),
          (o.jobsWaitingForRider, 'Deliveries without a rider', Icons.delivery_dining_outlined, 'Delivery'),
          (o.failedRefunds, 'Refunds that failed', Icons.money_off_outlined, 'Money'),
          (o.failedPayouts, 'Payouts that failed', Icons.payments_outlined, 'Payouts'),
          (o.failedNotifications24h, 'Messages not delivered (24 h)', Icons.chat_outlined, 'Messages'),
        ].where((a) => a.$1 > 0).toList();
        return RefreshIndicator(
          onRefresh: () => ref.refresh(_overviewProvider.future),
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 24), children: [
            Row(children: [
              Expanded(child: Text('Overview', style: theme.textTheme.headlineSmall)),
              IconButton(tooltip: 'Refresh', onPressed: () => ref.invalidate(_overviewProvider), icon: const Icon(Icons.refresh)),
            ]),
            Text('Today, ${DateFormat('EEEE d MMMM').format(DateTime.now())}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, c) {
              final columns = c.maxWidth >= 1000 ? 4 : 2;
              final tiles = [
                StatTile(label: 'Orders today', value: '${o.ordersToday}', icon: Icons.receipt_long_outlined,
                    hint: '${o.completedToday} completed · ${o.cancelledToday} cancelled'),
                StatTile(label: 'Order value today', value: formatInr(o.valueTodayMinor), icon: Icons.currency_rupee),
                StatTile(label: 'Live shops', value: '${o.liveShops}', icon: Icons.storefront_outlined,
                    hint: o.shopsWaitingForReview > 0 ? '${o.shopsWaitingForReview} waiting for review' : null),
                StatTile(label: 'Customers', value: '${o.customers}', icon: Icons.people_outline,
                    hint: '${o.newCustomersThisWeek} new this week'),
              ];
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: columns == 4 ? 2.1 : 1.9,
                children: tiles,
              );
            }),
            const SizedBox(height: 12),
            DailyBars(title: 'Orders, last 7 days', days: o.last7Days),
            const SizedBox(height: 20),
            Text('Needs attention', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (attention.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text('All clear'),
                  subtitle: Text('Nothing is waiting on you right now.'),
                ),
              ),
            for (final (count, label, icon, page) in attention)
              Card(
                color: theme.colorScheme.primaryContainer,
                child: ListTile(
                  leading: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
                  title: Text(label),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('$count', style: theme.textTheme.titleLarge),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right),
                  ]),
                  onTap: () => onOpen(page),
                ),
              ),
          ]),
        );
      },
    );
  }
}

/// Help requests: the queue on the left, the conversation on the right.
class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});

  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  TicketStatus? _status = TicketStatus.OPEN;
  String? _selected;
  int _reload = 0;

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final date = DateFormat('d MMM, h:mm a');
    final list = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Support', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(width: 8),
          for (final s in [TicketStatus.OPEN, TicketStatus.ANSWERED, TicketStatus.CLOSED, null])
            ChoiceChip(
              label: Text(s == null ? 'All' : s.label),
              selected: _status == s,
              onSelected: (_) => setState(() => _status = s),
            ),
          IconButton(tooltip: 'Refresh', onPressed: () => setState(() => _reload++), icon: const Icon(Icons.refresh)),
        ]),
      ),
      Expanded(
        child: PagedList<TicketSummary>(
          queryKey: (_status, _reload),
          padding: const EdgeInsets.fromLTRB(24, 0, 16, 24),
          separator: 8,
          fetch: (page) => api.supportQueue(status: _status, page: page),
          empty: EmptyView(
            icon: Icons.support_agent_outlined,
            title: _status == TicketStatus.OPEN ? 'No one is waiting for an answer' : 'No requests',
          ),
          itemBuilder: (context, t) => Card(
            color: t.id == _selected ? Theme.of(context).colorScheme.tertiaryContainer : null,
            child: ListTile(
              title: Text(t.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text([
                t.code,
                switch (t.openerRole) {
                  Role.VENDOR => 'Shop',
                  Role.DELIVERY_AGENT => 'Rider',
                  _ => 'Customer',
                },
                t.openerName ?? t.openerPhone ?? '',
                t.topic.label,
                date.format(t.lastMessageAt),
              ].join(' · ')),
              trailing: StatusChip(label: t.status.label, color: ticketStatusColor(t.status)),
              onTap: () async {
                if (wide) {
                  setState(() => _selected = t.id);
                } else {
                  await Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => TicketScreen(ticketId: t.id, staff: true)));
                  setState(() => _reload++);
                }
              },
            ),
          ),
        ),
      ),
    ]);
    if (!wide) return list;
    return Row(children: [
      SizedBox(width: 520, child: list),
      const VerticalDivider(width: 1),
      Expanded(
        child: _selected == null
            ? const EmptyView(icon: Icons.forum_outlined, title: 'Choose a request to answer')
            : TicketScreen(
                key: ValueKey(_selected),
                ticketId: _selected!,
                staff: true,
                embedded: true,
                onChanged: () => setState(() => _reload++),
              ),
      ),
    ]);
  }
}

/// Every review, with a way to hide abusive ones (they then leave the shop's average too).
class ReviewsPage extends ConsumerStatefulWidget {
  const ReviewsPage({super.key});

  @override
  ConsumerState<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends ConsumerState<ReviewsPage> {
  bool _hiddenOnly = false;
  int _reload = 0;

  Future<void> _toggle(AdminReview r) async {
    String? reason;
    if (!r.hidden) {
      reason = await askReason(context, title: 'Hide this review?', action: 'Hide');
      if (reason == null) return;
    }
    try {
      await ref.read(apiProvider).setReviewHidden(r.id, !r.hidden, reason: reason);
      setState(() => _reload++);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final date = DateFormat('d MMM yyyy');
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Reviews', style: theme.textTheme.headlineSmall),
          const SizedBox(width: 8),
          ChoiceChip(label: const Text('All'), selected: !_hiddenOnly, onSelected: (_) => setState(() => _hiddenOnly = false)),
          ChoiceChip(label: const Text('Hidden'), selected: _hiddenOnly, onSelected: (_) => setState(() => _hiddenOnly = true)),
          IconButton(tooltip: 'Refresh', onPressed: () => setState(() => _reload++), icon: const Icon(Icons.refresh)),
        ]),
      ),
      Expanded(
        child: PagedList<AdminReview>(
          queryKey: (_hiddenOnly, _reload),
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          separator: 8,
          fetch: (page) => api.adminReviews(hiddenOnly: _hiddenOnly, page: page),
          empty: EmptyView(icon: Icons.star_outline_rounded, title: _hiddenOnly ? 'No hidden reviews' : 'No reviews yet'),
          itemBuilder: (context, r) => Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Stars(rating: r.rating.toDouble()),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          [r.vendorName ?? '', r.customerPhone ?? '', r.orderCode ?? '', date.format(r.createdAt)].join(' · '),
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    if (r.comment != null) ...[const SizedBox(height: 4), Text(r.comment!)],
                    if (r.reply != null)
                      Text('Shop replied: ${r.reply}', style: theme.textTheme.bodySmall),
                    if (r.hidden)
                      Text('Hidden${r.hiddenReason == null ? '' : ': ${r.hiddenReason}'}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                  ]),
                ),
                TextButton(onPressed: () => _toggle(r), child: Text(r.hidden ? 'Show again' : 'Hide')),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}
