import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'shop_form_screen.dart';

final _earnings = FutureProvider.autoDispose<Earnings>((ref) => ref.watch(apiProvider).earnings());

/// What the shop has earned, what Mintadeal deducted, and payouts to the shop's account.
class EarningsTab extends ConsumerWidget {
  const EarningsTab({super.key, required this.shop});

  final Vendor shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnings = ref.watch(_earnings);
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: AsyncView(
        value: earnings,
        onRetry: () => ref.invalidate(_earnings),
        data: (e) => RefreshIndicator(
          onRefresh: () => ref.refresh(_earnings.future),
          child: _body(context, e),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Earnings e) {
    final theme = Theme.of(context);
    final date = DateFormat('d MMM, h:mm a');
    final owes = e.balanceMinor < 0;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        color: owes ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(owes ? 'You owe Mintadeal' : 'Mintadeal owes you', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(formatInr(e.balanceMinor.abs()), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(owes
                ? 'Commission on pay-on-delivery orders and delivery charges. It is taken from your next online earnings.'
                : 'Paid to you in the next payout.'),
            if (e.inPayoutMinor > 0) ...[
              const SizedBox(height: 8),
              Text('${formatInr(e.inPayoutMinor)} is on its way to your account', style: theme.textTheme.bodyMedium),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 8),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.account_balance_outlined),
        title: Text(e.payoutDestination ?? 'No payout account yet'),
        subtitle: Text(e.payoutDestination == null
            ? 'Add a UPI ID or bank account in My shop to receive payouts'
            : 'Where your payouts go'),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopFormScreen(existing: shop))),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.percent),
        title: Text('Mintadeal commission: ${bpsLabel(e.commissionBps)}'),
        subtitle: const Text('Of the item price on completed orders. Your delivery fee stays with you.'),
      ),
      if (e.payouts.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Payouts', style: theme.textTheme.titleMedium),
        for (final p in e.payouts)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(p.status == PayoutStatus.PAID ? Icons.check_circle_outline : Icons.schedule,
                color: p.status == PayoutStatus.PAID ? Colors.green.shade700 : null),
            title: Text('${formatInr(p.amountMinor)} · ${p.status.label}'),
            subtitle: Text([
              p.destination,
              date.format(p.paidAt ?? p.createdAt),
              if (p.utr != null) 'Ref ${p.utr}',
              if (p.failureReason != null) p.failureReason!,
            ].join(' · ')),
          ),
      ],
      const SizedBox(height: 8),
      Text('Statement', style: theme.textTheme.titleMedium),
      if (e.statement.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('Completed orders, commission and delivery charges will appear here.'),
        ),
      for (final l in e.statement)
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(l.description),
          subtitle: Text(date.format(l.createdAt)),
          trailing: Text(
            '${l.amountMinor >= 0 ? '+' : '−'}${formatInr(l.amountMinor.abs())}',
            style: theme.textTheme.titleSmall?.copyWith(
                color: l.amountMinor >= 0 ? Colors.green.shade700 : theme.colorScheme.onSurface),
          ),
        ),
    ]);
  }
}
