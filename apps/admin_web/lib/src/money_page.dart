import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

final _summary = FutureProvider.autoDispose<FinanceSummary>((ref) => ref.watch(apiProvider).financeSummary());
final _balances = FutureProvider.autoDispose<List<VendorBalance>>((ref) => ref.watch(apiProvider).vendorBalances());
final _refunds = FutureProvider.autoDispose<List<RefundRow>>((ref) => ref.watch(apiProvider).failedRefunds());
final _rates = FutureProvider.autoDispose<CommissionRates>((ref) => ref.watch(apiProvider).commissionRates());

/// Where the money is, from the ledger: what the payment provider holds, what is owed to and by shops,
/// and what Mintadeal has earned.
class MoneyPage extends ConsumerWidget {
  const MoneyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(_summary);
    final theme = Theme.of(context);
    void refresh() {
      ref.invalidate(_summary);
      ref.invalidate(_balances);
      ref.invalidate(_refunds);
    }

    return ListView(padding: const EdgeInsets.all(24), children: [
      Row(children: [
        Text('Money', style: theme.textTheme.headlineSmall),
        const SizedBox(width: 8),
        IconButton(tooltip: 'Refresh', onPressed: refresh, icon: const Icon(Icons.refresh)),
      ]),
      const SizedBox(height: 12),
      AsyncView(
        value: summary,
        onRetry: refresh,
        data: (s) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!s.balanced)
            Card(
              color: theme.colorScheme.errorContainer,
              child: const ListTile(
                leading: Icon(Icons.warning_amber),
                title: Text('The ledger does not balance'),
                subtitle: Text('Stop payouts and investigate before moving any more money.'),
              ),
            ),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _Tile('Held at Razorpay', s.gatewayMinor, 'Customer payments received, minus refunds and payouts'),
            _Tile('Paid for open orders', s.customerPrepaidMinor, "Customers' money until their orders complete"),
            _Tile('Owed to shops', s.owedToShopsMinor, 'Earnings not yet in a payout'),
            _Tile('Owed by shops', s.owedByShopsMinor, 'Commission and delivery charges not yet netted'),
            _Tile('Payouts on the way', s.payoutsInTransitMinor, '${s.pendingPayouts} payouts pending or processing'),
            _Tile('Commission earned', s.commissionRevenueMinor, 'On completed orders'),
            _Tile('Delivery charges recovered', s.deliveryRecoveryMinor, 'Partner delivery fees charged to shops'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(s.balanced ? Icons.verified_outlined : Icons.error_outline,
                size: 18, color: s.balanced ? Colors.green.shade700 : theme.colorScheme.error),
            const SizedBox(width: 6),
            Text(s.balanced ? 'Every journal balances (double-entry ledger)' : 'Ledger out of balance'),
          ]),
        ]),
      ),
      const SizedBox(height: 32),
      const _CommissionEditor(),
      const SizedBox(height: 32),
      Text('Failed refunds', style: theme.textTheme.titleLarge),
      const SizedBox(height: 8),
      const _FailedRefunds(),
      const SizedBox(height: 32),
      Text('Shop balances', style: theme.textTheme.titleLarge),
      const SizedBox(height: 8),
      const _Balances(),
    ]);
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.amountMinor, this.help);

  final String label;
  final int amountMinor;
  final String help;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(formatInr(amountMinor), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(help, style: theme.textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}

class _CommissionEditor extends ConsumerStatefulWidget {
  const _CommissionEditor();

  @override
  ConsumerState<_CommissionEditor> createState() => _CommissionEditorState();
}

class _CommissionEditorState extends ConsumerState<_CommissionEditor> {
  final _default = TextEditingController();
  final Map<VendorCategory, TextEditingController> _overrides = {};
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _default.dispose();
    for (final c in _overrides.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _pct(int bps) => (bps / 100).toStringAsFixed(bps % 100 == 0 ? 0 : 2);

  static int? _bps(String text) {
    final v = double.tryParse(text.trim().replaceAll('%', ''));
    return v == null ? null : (v * 100).round();
  }

  Future<void> _save() async {
    final def = _bps(_default.text);
    if (def == null) {
      showMessage(context, 'Enter the default commission as a percentage');
      return;
    }
    final overrides = <VendorCategory, int>{};
    for (final e in _overrides.entries) {
      final bps = _bps(e.value.text);
      if (e.value.text.trim().isNotEmpty && bps != null) overrides[e.key] = bps;
    }
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).saveCommissionRates(CommissionRates(def, overrides));
      ref.invalidate(_rates);
      if (mounted) showMessage(context, 'Saved. New rates apply to orders placed from now on.');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rates = ref.watch(_rates);
    final theme = Theme.of(context);
    if (!_loaded && rates.value != null) {
      _loaded = true;
      _default.text = _pct(rates.value!.defaultBps);
      for (final c in VendorCategory.values) {
        final bps = rates.value!.categoryBps[c];
        _overrides[c] = TextEditingController(text: bps == null ? '' : _pct(bps));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Commission', style: theme.textTheme.titleLarge),
      const Text('Taken on the item price when an order completes. Rates are fixed on each order when it is placed. '
          'Mintadeal own catalogue pays none.'),
      const SizedBox(height: 12),
      if (!_loaded)
        const LinearProgressIndicator()
      else
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _default,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Default', suffixText: '%'),
                  ),
                ),
                const SizedBox(height: 16),
                Text('By category (leave empty to use the default)', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final c in VendorCategory.values)
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _overrides[c],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: c.label, suffixText: '%', isDense: true),
                      ),
                    ),
                ]),
                const SizedBox(height: 16),
                FilledButton(onPressed: _saving ? null : _save, child: const Text('Save commission')),
              ]),
            ),
          ),
        ),
    ]);
  }
}

class _FailedRefunds extends ConsumerWidget {
  const _FailedRefunds();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refunds = ref.watch(_refunds);
    final date = DateFormat('d MMM, h:mm a');
    return AsyncView(
      value: refunds,
      onRetry: () => ref.invalidate(_refunds),
      data: (list) => list.isEmpty
          ? const Text('None. Every refund has gone through.')
          : Column(children: [
              for (final r in list)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.undo),
                    title: Text('${r.orderCode} · ${formatInr(r.amountMinor)}'),
                    subtitle: Text('${date.format(r.createdAt)} · ${r.error ?? ''}'),
                    trailing: OutlinedButton(
                      onPressed: () async {
                        try {
                          final result = await ref.read(apiProvider).retryRefund(r.id);
                          ref.invalidate(_refunds);
                          ref.invalidate(_summary);
                          if (context.mounted) {
                            showMessage(context, result.status == 'PROCESSED' ? 'Refunded' : 'Still failing: ${result.error}');
                          }
                        } catch (e) {
                          if (context.mounted) showError(context, e);
                        }
                      },
                      child: const Text('Retry refund'),
                    ),
                  ),
                ),
            ]),
    );
  }
}

class _Balances extends ConsumerWidget {
  const _Balances();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(_balances);
    return AsyncView(
      value: balances,
      onRetry: () => ref.invalidate(_balances),
      data: (list) => list.isEmpty
          ? const Text('No balances yet')
          : Card(
              child: Column(children: [
                for (final b in list)
                  ListTile(
                    title: Text(b.vendorName),
                    subtitle: Text(b.payoutDestination ?? 'No payout account'),
                    trailing: Text(
                      b.balanceMinor >= 0 ? 'Owed ${formatInr(b.balanceMinor)}' : 'Owes ${formatInr(-b.balanceMinor)}',
                      style: TextStyle(
                          color: b.balanceMinor >= 0 ? null : Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ]),
            ),
    );
  }
}
