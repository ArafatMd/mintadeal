import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

final _charges = FutureProvider.autoDispose<ShopCharges>((ref) => ref.watch(apiProvider).shopCharges());

/// Delivery partner fees the shop owes Mintadeal. They are deducted from payouts once payouts start.
class ChargesScreen extends ConsumerWidget {
  const ChargesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charges = ref.watch(_charges);
    final date = DateFormat('d MMM, h:mm a');
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery charges')),
      body: AsyncView(
        value: charges,
        onRetry: () => ref.invalidate(_charges),
        data: (c) => RefreshIndicator(
          onRefresh: () => ref.refresh(_charges.future),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: ListTile(
                title: const Text('Unpaid delivery charges'),
                subtitle: Text('You can book partners until this reaches ${formatInr(c.limitMinor)}'),
                trailing: Text(formatInr(c.outstandingMinor), style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            const SizedBox(height: 8),
            const Text('These are deducted from your payouts. Until payouts start, Mintadeal will contact you to settle them.'),
            const SizedBox(height: 16),
            if (c.charges.isEmpty) const EmptyView(icon: Icons.receipt_outlined, title: 'No delivery charges yet'),
            for (final ch in c.charges)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(ch.description),
                subtitle: Text('${date.format(ch.createdAt)} · ${ch.status.toLowerCase()}'),
                trailing: Text(formatInr(ch.amountMinor)),
              ),
          ]),
        ),
      ),
    );
  }
}
