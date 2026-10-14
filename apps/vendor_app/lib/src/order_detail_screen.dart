import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';
import 'package:url_launcher/url_launcher.dart';

import 'scan_screen.dart';

final _shopOrder = FutureProvider.autoDispose.family<OrderDetail, String>((ref, id) => ref.watch(apiProvider).shopOrder(id));

class ShopOrderScreen extends ConsumerStatefulWidget {
  const ShopOrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ShopOrderScreen> createState() => _ShopOrderScreenState();
}

class _ShopOrderScreenState extends ConsumerState<ShopOrderScreen> {
  bool _busy = false;

  static const _rejectReasons = [
    'Out of stock',
    'Shop is closed now',
    'Cannot deliver to this address',
    'Price has changed',
  ];

  Future<void> _act(OrderDetail o, OrderAction action) async {
    if (action == OrderAction.REDEEM) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanScreen()));
      ref.invalidate(_shopOrder(widget.orderId));
      return;
    }
    if (action == OrderAction.REQUEST_DELIVERY) {
      await _bookPartner(o);
      return;
    }
    if (action == OrderAction.CANCEL_DELIVERY) {
      await _run(() => ref.read(apiProvider).cancelDelivery(o.id));
      return;
    }
    String? reason;
    if (action == OrderAction.REJECT) {
      reason = await _askRejectReason();
      if (reason == null) return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).shopOrderAction(o.id, action, reason: reason);
      ref.invalidate(_shopOrder(widget.orderId));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(_shopOrder(widget.orderId));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Shows the partner's cost first; the shop confirms before anything is booked.
  Future<void> _bookPartner(OrderDetail o) async {
    final DeliveryCostQuote quote;
    try {
      quote = await ref.read(apiProvider).deliveryQuote(o.id);
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Book a delivery partner?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${quote.distanceKm.toStringAsFixed(1)} km to the customer'),
          const SizedBox(height: 8),
          Text('Cost to your shop: ${formatInr(quote.costMinor)}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Charged when the partner picks up the order, and deducted from your payout.'),
          if (o.paymentStatus != PaymentStatus.PAID) ...[
            const SizedBox(height: 8),
            Text('The partner collects ${formatInr(o.totalMinor)} from the customer for you.'),
          ],
          if (!quote.allowed) ...[
            const SizedBox(height: 12),
            Text(quote.problem ?? '', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          FilledButton(onPressed: quote.allowed ? () => Navigator.pop(context, true) : null, child: const Text('Book partner')),
        ],
      ),
    );
    if (ok == true) {
      await _run(() async {
        await ref.read(apiProvider).requestDelivery(o.id);
        if (mounted) showMessage(context, 'Delivery partner requested. Keep the order packed and ready.');
      });
    }
  }

  Future<String?> _askRejectReason() {
    final other = TextEditingController();
    String? chosen;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Why can you not take this order?'),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('The customer sees this reason.'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final r in _rejectReasons)
                  ChoiceChip(label: Text(r), selected: chosen == r, onSelected: (_) => setState(() => chosen = r)),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: other,
                decoration: const InputDecoration(labelText: 'Or write a reason'),
                onChanged: (_) => setState(() => chosen = null),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
            FilledButton(
              onPressed: (chosen ?? other.text.trim()).isEmpty
                  ? null
                  : () => Navigator.pop(context, chosen ?? other.text.trim()),
              child: const Text('Reject order'),
            ),
          ],
        ),
      ),
    );
  }

  String _actionLabel(OrderDetail o, OrderAction a) => switch (a) {
        OrderAction.ACCEPT => 'Accept order',
        OrderAction.REJECT => 'Reject',
        OrderAction.MARK_READY => 'Ready for pickup',
        OrderAction.OUT_FOR_DELIVERY =>
          o.fulfilmentMode == FulfilmentMode.PARTNER_DELIVERY ? 'Handed to delivery partner' : 'Out for delivery',
        OrderAction.COMPLETE => switch (o.fulfilmentMode) {
            FulfilmentMode.PICKUP => 'Customer collected it',
            FulfilmentMode.VENUE_QR => 'Customer used the offer',
            _ => 'Delivered',
          },
        OrderAction.REDEEM => 'Scan customer QR',
        OrderAction.REQUEST_DELIVERY => 'Book delivery partner',
        OrderAction.CANCEL_DELIVERY => 'Cancel partner',
        _ => a.label,
      };

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(_shopOrder(widget.orderId));
    return Scaffold(
      appBar: AppBar(title: Text(order.value?.code ?? 'Order')),
      body: AsyncView(
        value: order,
        onRetry: () => ref.invalidate(_shopOrder(widget.orderId)),
        data: (o) => RefreshIndicator(
          onRefresh: () => ref.refresh(_shopOrder(widget.orderId).future),
          child: _body(context, o),
        ),
      ),
      bottomNavigationBar: order.value == null || order.value!.actions.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  for (final (i, a) in order.value!.actions.reversed.indexed) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: a == OrderAction.REJECT || a == OrderAction.CANCEL_DELIVERY ? 1 : 2,
                      child: a == OrderAction.REJECT || a == OrderAction.CANCEL_DELIVERY
                          ? OutlinedButton(onPressed: _busy ? null : () => _act(order.value!, a), child: Text(_actionLabel(order.value!, a)))
                          : FilledButton(onPressed: _busy ? null : () => _act(order.value!, a), child: Text(_actionLabel(order.value!, a))),
                    ),
                  ],
                ]),
              ),
            ),
    );
  }

  Widget _body(BuildContext context, OrderDetail o) {
    final theme = Theme.of(context);
    final time = DateFormat('d MMM, h:mm a');
    final paid = o.paymentStatus == PaymentStatus.PAID;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
      Row(children: [
        StatusChip(label: o.status.label, color: o.status.isOpen ? theme.colorScheme.primary : Colors.grey.shade700),
        const Spacer(),
        Text(time.format(o.createdAt), style: theme.textTheme.bodySmall),
      ]),
      if (o.status == OrderStatus.PLACED && o.acceptDeadline != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Accept by ${DateFormat('h:mm a').format(o.acceptDeadline!)} or it is cancelled automatically.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.secondary)),
        ),
      if (o.status == OrderStatus.CANCELLED)
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(o.cancelReason ?? 'Cancelled')),
      const SizedBox(height: 12),
      Card(
        color: paid ? Colors.green.withValues(alpha: 0.1) : theme.colorScheme.secondaryContainer,
        child: ListTile(
          leading: Icon(paid ? Icons.verified_outlined : Icons.payments_outlined),
          title: Text(paid ? 'Paid online' : 'Collect ${formatInr(o.totalMinor)} from the customer'),
          subtitle: Text(paid ? 'Do not collect money for this order' : 'Cash or UPI on ${o.fulfilmentMode == FulfilmentMode.PICKUP ? 'pickup' : 'delivery'}'),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: ListTile(
          leading: Icon(o.fulfilmentMode.icon),
          title: Text(o.customer?.name ?? 'Customer'),
          subtitle: Text([
            o.fulfilmentMode.label,
            if (o.address != null) [o.address!.line, o.address!.landmark, o.address!.area].whereType<String>().join(', '),
          ].join('\n')),
          isThreeLine: o.address != null,
          trailing: o.customer?.phone == null
              ? null
              : IconButton(
                  tooltip: 'Call customer',
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: o.customer!.phone)),
                  icon: const Icon(Icons.call_outlined),
                ),
        ),
      ),
      if (o.delivery != null) ...[
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.delivery_dining),
            title: Text(o.delivery!.status.label),
            subtitle: Text([
              if (o.delivery!.agentName != null) 'Partner: ${o.delivery!.agentName}',
              if (o.delivery!.costMinor != null) 'Cost to shop: ${formatInr(o.delivery!.costMinor!)}',
              if (o.delivery!.failureReason != null) o.delivery!.failureReason!,
            ].join('\n')),
            trailing: o.delivery!.agentPhone == null
                ? null
                : IconButton(
                    tooltip: 'Call delivery partner',
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: o.delivery!.agentPhone)),
                    icon: const Icon(Icons.call_outlined),
                  ),
          ),
        ),
      ],
      if (o.redemption != null) ...[
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.qr_code_2),
            title: Text(o.redemption!.usedAt != null
                ? 'Used ${DateFormat('d MMM, h:mm a').format(o.redemption!.usedAt!)}'
                : 'Customer shows a QR code at your venue'),
            subtitle: Text('For ${o.redemption!.quantity} ${o.redemption!.quantity == 1 ? 'person' : 'people'}'
                '${o.redemption!.validTo == null ? '' : ' · valid until ${DateFormat('d MMM yyyy').format(o.redemption!.validTo!)}'}'),
          ),
        ),
      ],
      if (o.note != null) ...[
        const SizedBox(height: 8),
        Card(child: ListTile(leading: const Icon(Icons.sticky_note_2_outlined), title: const Text('Note'), subtitle: Text(o.note!))),
      ],
      const SizedBox(height: 16),
      Text('Items', style: theme.textTheme.titleMedium),
      for (final l in o.lines)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Text('${l.quantity}×')),
          title: Text(l.title),
          subtitle: Text(formatInr(l.unitPriceMinor)),
          trailing: Text(formatInr(l.lineTotalMinor)),
        ),
      if (o.deliveryFeeMinor > 0)
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Delivery fee'), trailing: Text(formatInr(o.deliveryFeeMinor))),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Total', style: theme.textTheme.titleMedium),
        trailing: Text(formatInr(o.totalMinor), style: theme.textTheme.titleMedium),
      ),
      const SizedBox(height: 16),
      Text('History', style: theme.textTheme.titleMedium),
      for (final e in o.events.reversed)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.circle, size: 10),
          title: Text(e.note ?? e.status.label),
          subtitle: Text(time.format(e.createdAt)),
        ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => NewTicketScreen(as: Role.VENDOR, orderId: o.id, orderCode: o.code, topics: const [
                  TicketTopic.ORDER, TicketTopic.PAYMENT_REFUND, TicketTopic.DELIVERY, TicketTopic.OTHER,
                ]))),
        icon: const Icon(Icons.support_agent_outlined),
        label: const Text('Get help with this order'),
      ),
    ]);
  }
}
