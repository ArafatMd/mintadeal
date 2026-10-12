import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'dialogs.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  OrderStatus? _status;
  String _q = '';
  int _reload = 0;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final date = DateFormat('d MMM, h:mm a');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Orders', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(width: 16),
          SizedBox(
            width: 320,
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Order code, customer phone or shop',
                isDense: true,
              ),
              onChanged: (t) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _q = t.trim()));
              },
            ),
          ),
          IconButton(tooltip: 'Refresh', onPressed: () => setState(() => _reload++), icon: const Icon(Icons.refresh)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in [null, ...OrderStatus.values])
            ChoiceChip(
              label: Text(s == null ? 'All' : s.label),
              selected: _status == s,
              onSelected: (_) => setState(() => _status = s),
            ),
        ]),
      ),
      Expanded(
        child: PagedList<OrderSummary>(
          queryKey: (_status, _q, _reload),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          separator: 8,
          fetch: (page) => api.adminOrders(status: _status, q: _q.isEmpty ? null : _q, page: page),
          empty: const EmptyView(icon: Icons.receipt_long_outlined, title: 'No orders match'),
          itemBuilder: (context, o) => Card(
            child: ListTile(
              leading: CircleAvatar(child: Icon(o.fulfilmentMode.icon)),
              title: Text('${o.code} · ${o.vendorName}'),
              subtitle: Text([
                '${o.firstItemTitle ?? ''}${o.itemCount > 1 ? ' + ${o.itemCount - 1} more' : ''}',
                o.paymentStatus == PaymentStatus.PAID ? 'paid online' : o.paymentStatus.label.toLowerCase(),
                date.format(o.createdAt),
              ].join(' · ')),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(formatInr(o.totalMinor)),
                const SizedBox(width: 12),
                StatusChip(label: o.status.label, color: o.status.isOpen ? Theme.of(context).colorScheme.primary : Colors.grey.shade700),
              ]),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminOrderPage(orderId: o.id)));
                setState(() => _reload++);
              },
            ),
          ),
        ),
      ),
    ]);
  }
}

final _adminOrder = FutureProvider.autoDispose.family<OrderDetail, String>((ref, id) => ref.watch(apiProvider).adminOrder(id));

class AdminOrderPage extends ConsumerWidget {
  const AdminOrderPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(_adminOrder(orderId));
    final date = DateFormat('d MMM yyyy, h:mm:ss a');
    return Scaffold(
      appBar: AppBar(title: Text(order.value?.code ?? 'Order')),
      body: AsyncView(
        value: order,
        onRetry: () => ref.invalidate(_adminOrder(orderId)),
        data: (o) {
          final theme = Theme.of(context);
          final facts = <(String, String?)>[
            ('Status', o.status.label),
            ('Checkout', o.checkoutCode),
            ('Shop', '${o.shop.name} · ${o.shop.phone ?? ''}'),
            ('Customer', '${o.customer?.name ?? ''} · ${o.customer?.phone ?? ''}'),
            ('Fulfilment', o.fulfilmentMode.label),
            ('Address', o.address == null ? null : [o.address!.line, o.address!.landmark, o.address!.area].whereType<String>().join(', ')),
            ('Note', o.note),
            ('Payment', o.paymentStatus == PaymentStatus.NOT_REQUIRED ? o.paymentMethod.label : '${o.paymentMethod.label} · ${o.paymentStatus.label}'),
            ('Total', '${formatInr(o.totalMinor)} (items ${formatInr(o.itemsTotalMinor)}, delivery ${formatInr(o.deliveryFeeMinor)})'),
            ('Accept by', o.acceptDeadline == null ? null : date.format(o.acceptDeadline!)),
            ('Cancelled', o.cancelReason == null ? null : '${o.cancelledBy?.toLowerCase()}: ${o.cancelReason}'),
            ('Refund', o.refundStatus == null ? null : '${o.refundStatus!.label} · ${formatInr(o.refundAmountMinor ?? 0)}'),
          ];
          return ListView(padding: const EdgeInsets.all(24), children: [
            if (o.actions.contains(OrderAction.CANCEL))
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(o.paymentStatus == PaymentStatus.PAID ? 'Cancel and refund' : 'Cancel order'),
                  onPressed: () async {
                    final reason = await askReason(context, title: 'Cancel ${o.code}', action: 'Cancel order');
                    if (reason == null) return;
                    try {
                      await ref.read(apiProvider).adminCancelOrder(o.id, reason);
                      ref.invalidate(_adminOrder(orderId));
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  },
                ),
              ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  for (final (k, v) in facts)
                    if (v != null && v.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(width: 160, child: Text(k, style: theme.textTheme.bodySmall)),
                          Expanded(child: SelectableText(v)),
                        ]),
                      ),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            Text('Items', style: theme.textTheme.titleMedium),
            for (final l in o.lines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.title),
                subtitle: Text('${l.quantity} × ${formatInr(l.unitPriceMinor)}'
                    '${l.originalPriceMinor > l.unitPriceMinor ? ' (list price ${formatInr(l.originalPriceMinor)})' : ''}'),
                trailing: Text(formatInr(l.lineTotalMinor)),
              ),
            const SizedBox(height: 16),
            Text('Event trail', style: theme.textTheme.titleMedium),
            for (final e in o.events)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.history),
                title: Text('${e.status.label} · ${e.actorType.toLowerCase()}'),
                subtitle: Text([date.format(e.createdAt), if (e.note != null) e.note!].join(' · ')),
              ),
          ]);
        },
      ),
    );
  }
}
