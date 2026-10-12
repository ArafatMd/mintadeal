import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';
import 'package:url_launcher/url_launcher.dart';

import 'payment_screen.dart';
import 'sign_in.dart';

/// Bumped after placing or changing an order so the orders list reloads.
final myOrdersRefreshProvider = Provider.autoDispose<int>((ref) => DateTime.now().millisecondsSinceEpoch);

Color orderStatusColor(BuildContext context, OrderStatus s) => switch (s) {
      OrderStatus.PENDING_PAYMENT || OrderStatus.PLACED => Colors.orange.shade800,
      OrderStatus.ACCEPTED || OrderStatus.READY || OrderStatus.OUT_FOR_DELIVERY => Theme.of(context).colorScheme.primary,
      OrderStatus.COMPLETED => Colors.green.shade700,
      OrderStatus.CANCELLED => Colors.grey.shade700,
    };

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(sessionProvider).value != null;
    final refresh = ref.watch(myOrdersRefreshProvider);
    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Orders')),
        body: EmptyView(
          icon: Icons.receipt_long_outlined,
          title: 'Your orders appear here',
          action: FilledButton(onPressed: () => ensureSignedIn(context, ref), child: const Text('Sign in')),
        ),
      );
    }
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: PagedList<OrderSummary>(
        queryKey: refresh,
        fetch: (page) => api.myOrders(page: page),
        empty: const EmptyView(
          icon: Icons.receipt_long_outlined,
          title: 'No orders yet',
          message: 'Order from shops near you and track it here.',
        ),
        itemBuilder: (context, o) => OrderTile(
          order: o,
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id)));
            ref.invalidate(myOrdersRefreshProvider);
          },
        ),
      ),
    );
  }
}

class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order, required this.onTap, this.title});

  final OrderSummary order;
  final VoidCallback onTap;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final more = order.itemCount > 1 ? ' and ${order.itemCount - 1} more' : '';
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Icon(order.fulfilmentMode.icon)),
        title: Text(title ?? order.vendorName),
        subtitle: Text('${order.firstItemTitle ?? ''}$more\n${order.code} · ${timeAgo(order.createdAt)}'),
        isThreeLine: true,
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(formatInr(order.totalMinor), style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          StatusChip(label: order.status.label, color: orderStatusColor(context, order.status)),
        ]),
      ),
    );
  }
}

/// Shown right after a pay-on-delivery order goes through.
class OrderPlacedScreen extends StatelessWidget {
  const OrderPlacedScreen({super.key, required this.result});

  final CheckoutResult result;

  @override
  Widget build(BuildContext context) {
    final multi = result.orders.length > 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Order placed')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const SizedBox(height: 24),
        Icon(Icons.check_circle, size: 64, color: Colors.green.shade600),
        const SizedBox(height: 12),
        Text('Order ${result.code}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          multi
              ? 'Your cart was split into ${result.orders.length} orders, one per shop. Each shop accepts and fulfils its own.'
              : 'The shop will accept it shortly. You will see updates in Orders.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        for (final o in result.orders) ...[
          OrderTile(
            order: o,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id))),
          ),
          const SizedBox(height: 8),
        ],
      ]),
    );
  }
}

final _orderProvider = FutureProvider.autoDispose.family<OrderDetail, String>((ref, id) => ref.watch(apiProvider).myOrder(id));

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Timer? _poll;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Keep the status fresh while the customer watches it.
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      final o = ref.read(_orderProvider(widget.orderId)).value;
      if (o != null && o.status.isOpen) ref.invalidate(_orderProvider(widget.orderId));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _cancel(OrderDetail o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(o.status == OrderStatus.PENDING_PAYMENT
            ? 'Nothing has been charged. All orders from this checkout are cancelled.'
            : o.paymentStatus == PaymentStatus.PAID
                ? 'You will get a refund of ${formatInr(o.totalMinor)} to your original payment method.'
                : 'The shop will be told.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep order')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel order')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).cancelMyOrder(o.id);
      ref.invalidate(_orderProvider(widget.orderId));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(_orderProvider(widget.orderId));
    return Scaffold(
      appBar: AppBar(title: Text(order.value?.code ?? 'Order')),
      body: AsyncView(
        value: order,
        onRetry: () => ref.invalidate(_orderProvider(widget.orderId)),
        data: (o) => RefreshIndicator(
          onRefresh: () => ref.refresh(_orderProvider(widget.orderId).future),
          child: _body(context, o),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, OrderDetail o) {
    final theme = Theme.of(context);
    final time = DateFormat('d MMM, h:mm a');
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
      Row(children: [
        StatusChip(label: o.status.label, color: orderStatusColor(context, o.status)),
        const Spacer(),
        Text(time.format(o.createdAt), style: theme.textTheme.bodySmall),
      ]),
      const SizedBox(height: 12),
      _StatusSteps(order: o),
      if (o.status == OrderStatus.PLACED && o.acceptDeadline != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('If the shop does not accept by ${DateFormat('h:mm a').format(o.acceptDeadline!)}, '
              'the order is cancelled automatically${o.paymentStatus == PaymentStatus.PAID ? ' and refunded' : ''}.',
              style: theme.textTheme.bodySmall),
        ),
      if (o.status == OrderStatus.CANCELLED && o.cancelReason != null)
        Card(
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text([
              o.cancelReason!,
              if (o.refundStatus != null) '${o.refundStatus!.label}: ${formatInr(o.refundAmountMinor ?? 0)}',
            ].join('\n')),
          ),
        ),
      if (o.fulfilmentMode == FulfilmentMode.VENUE_QR && o.status == OrderStatus.ACCEPTED)
        Card(
          child: ListTile(
            leading: const Icon(Icons.qr_code_2, size: 36),
            title: Text('Show order ${o.code} at the venue'),
            subtitle: const Text('A scannable QR code arrives in the next update. Until then the shop checks this order number.'),
          ),
        ),
      const SizedBox(height: 16),
      Card(
        child: ListTile(
          leading: const Icon(Icons.storefront_outlined),
          title: Text(o.shop.name ?? ''),
          subtitle: Text(o.fulfilmentMode == FulfilmentMode.PICKUP || o.fulfilmentMode == FulfilmentMode.VENUE_QR
              ? 'Address: ${o.shopAddress ?? ''}'
              : o.fulfilmentMode.label),
          trailing: o.shop.phone == null
              ? null
              : IconButton(
                  tooltip: 'Call shop',
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: o.shop.phone)),
                  icon: const Icon(Icons.call_outlined),
                ),
        ),
      ),
      if (o.address != null) ...[
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Delivering to'),
            subtitle: Text([o.address!.line, o.address!.landmark, o.address!.area].whereType<String>().join(', ')),
          ),
        ),
      ],
      const SizedBox(height: 16),
      Text('Items', style: theme.textTheme.titleMedium),
      for (final l in o.lines)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.title),
          subtitle: Text('${l.quantity} × ${formatInr(l.unitPriceMinor)}'),
          trailing: Text(formatInr(l.lineTotalMinor)),
        ),
      if (o.deliveryFeeMinor > 0)
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Delivery'), trailing: Text(formatInr(o.deliveryFeeMinor))),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Total', style: theme.textTheme.titleMedium),
        subtitle: Text(o.paymentStatus == PaymentStatus.PAID
            ? 'Paid online'
            : o.paymentMethod == PaymentMethod.PAY_ON_DELIVERY
                ? 'Pay the shop on ${o.fulfilmentMode == FulfilmentMode.PICKUP ? 'pickup' : 'delivery'}'
                : o.paymentStatus.label),
        trailing: Text(formatInr(o.totalMinor), style: theme.textTheme.titleMedium),
      ),
      const SizedBox(height: 8),
      if (o.actions.contains(OrderAction.PAY))
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PaymentScreen(checkoutId: o.checkoutId, openNow: true))),
          icon: const Icon(Icons.payment),
          label: const Text('Pay now'),
        ),
      if (o.actions.contains(OrderAction.CANCEL)) ...[
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _busy ? null : () => _cancel(o), child: const Text('Cancel order')),
      ],
      const SizedBox(height: 24),
      Text('History', style: theme.textTheme.titleMedium),
      for (final e in o.events.reversed)
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.circle, size: 10),
          title: Text(e.note ?? e.status.label),
          subtitle: Text(time.format(e.createdAt)),
        ),
    ]);
  }
}

/// A simple progress line for the order's fulfilment path.
class _StatusSteps extends StatelessWidget {
  const _StatusSteps({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    if (order.status == OrderStatus.CANCELLED) return const SizedBox.shrink();
    final steps = switch (order.fulfilmentMode) {
      FulfilmentMode.PICKUP => [OrderStatus.PLACED, OrderStatus.ACCEPTED, OrderStatus.READY, OrderStatus.COMPLETED],
      FulfilmentMode.VENUE_QR => [OrderStatus.PENDING_PAYMENT, OrderStatus.ACCEPTED, OrderStatus.COMPLETED],
      _ => [OrderStatus.PLACED, OrderStatus.ACCEPTED, OrderStatus.OUT_FOR_DELIVERY, OrderStatus.COMPLETED],
    };
    const labels = {
      OrderStatus.PENDING_PAYMENT: 'Paid',
      OrderStatus.PLACED: 'Placed',
      OrderStatus.ACCEPTED: 'Accepted',
      OrderStatus.READY: 'Ready',
      OrderStatus.OUT_FOR_DELIVERY: 'On the way',
      OrderStatus.COMPLETED: 'Done',
    };
    var reached = steps.indexOf(order.status);
    if (order.status == OrderStatus.PENDING_PAYMENT) reached = -1;
    if (reached < 0 && order.status == OrderStatus.PLACED) reached = 0;
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      for (final (i, s) in steps.indexed) ...[
        if (i > 0) Expanded(child: Container(height: 3, color: i <= reached ? scheme.primary : scheme.outlineVariant)),
        Column(children: [
          Icon(i <= reached ? Icons.check_circle : Icons.radio_button_unchecked,
              color: i <= reached ? scheme.primary : scheme.outline, size: 22),
          const SizedBox(height: 2),
          Text(labels[s]!, style: Theme.of(context).textTheme.labelSmall),
        ]),
      ],
    ]);
  }
}
