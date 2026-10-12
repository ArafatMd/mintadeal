import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'order_alerts.dart';
import 'order_detail_screen.dart';

class OrdersTab extends ConsumerStatefulWidget {
  const OrdersTab({super.key});

  @override
  ConsumerState<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<OrdersTab> {
  String _filter = 'NEW';
  int _reload = 0;

  @override
  void initState() {
    super.initState();
    newOrderTick.addListener(_onNewOrder);
  }

  @override
  void dispose() {
    newOrderTick.removeListener(_onNewOrder);
    super.dispose();
  }

  void _onNewOrder() {
    if (mounted) setState(() => _reload++);
  }

  @override
  Widget build(BuildContext context) {
    final counts = ref.watch(orderCountsProvider);
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'NEW', label: Text('New${(counts?.newOrders ?? 0) > 0 ? ' (${counts!.newOrders})' : ''}')),
              ButtonSegment(
                  value: 'ACTIVE', label: Text('In progress${(counts?.activeOrders ?? 0) > 0 ? ' (${counts!.activeOrders})' : ''}')),
              const ButtonSegment(value: 'DONE', label: Text('Done')),
            ],
            selected: {_filter},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
        ),
        Expanded(
          child: PagedList<OrderSummary>(
            queryKey: (_filter, _reload),
            fetch: (page) => api.shopOrders(_filter, page: page),
            empty: EmptyView(
              icon: Icons.receipt_long_outlined,
              title: switch (_filter) {
                'NEW' => 'No new orders',
                'ACTIVE' => 'Nothing in progress',
                _ => 'No finished orders yet',
              },
              message: _filter == 'NEW' ? 'New orders appear here. Keep this app open to hear the alert.' : null,
            ),
            itemBuilder: (context, o) => _OrderCard(
              order: o,
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopOrderScreen(orderId: o.id)));
                ref.read(orderCountsProvider.notifier).refresh();
                setState(() => _reload++);
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final more = order.itemCount > 1 ? ' + ${order.itemCount - 1} more' : '';
    final deadline = order.status == OrderStatus.PLACED ? order.acceptDeadline : null;
    final minutesLeft = deadline?.difference(DateTime.now()).inMinutes;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            CircleAvatar(child: Icon(order.fulfilmentMode.icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${order.firstItemTitle ?? ''}$more', style: theme.textTheme.titleSmall,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${order.code} · ${order.fulfilmentMode.label} · ${timeAgo(order.createdAt)}',
                    style: theme.textTheme.bodySmall),
                if (minutesLeft != null)
                  Text(minutesLeft > 0 ? 'Accept within $minutesLeft min' : 'Accept now',
                      style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.secondary)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(formatInr(order.totalMinor), style: theme.textTheme.titleSmall),
              Text(order.paymentStatus == PaymentStatus.PAID ? 'Paid online' : 'Collect payment',
                  style: theme.textTheme.labelSmall),
            ]),
          ]),
        ),
      ),
    );
  }
}
