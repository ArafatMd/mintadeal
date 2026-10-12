import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mintadeal_core/mintadeal_core.dart';

import 'dialogs.dart';

/// Pay shops what they are owed: create a batch, then send it through RazorpayX or record bank transfers.
class PayoutsPage extends ConsumerStatefulWidget {
  const PayoutsPage({super.key});

  @override
  ConsumerState<PayoutsPage> createState() => _PayoutsPageState();
}

class _PayoutsPageState extends ConsumerState<PayoutsPage> {
  String _status = 'OPEN';
  int _reload = 0;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      setState(() => _reload++);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createBatch() => _run(() async {
        final r = await ref.read(apiProvider).createPayoutBatch();
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(r.payoutCount == 0 ? 'Nothing to pay' : '${r.payoutCount} ${r.payoutCount == 1 ? 'payout' : 'payouts'} created'),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (r.payoutCount > 0) Text('Total ${formatInr(r.totalMinor)}. Send them, or pay by bank and record the reference.'),
              if (r.payoutCount == 0) const Text('No shop has a balance above the minimum payout.'),
              if (r.skipped.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Not included:'),
                for (final s in r.skipped) Text('• $s'),
              ],
            ]),
            actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      });

  Future<void> _markPaid(PayoutView p) async {
    final utr = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Record payment to ${p.vendorName}'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pay ${formatInr(p.amountMinor)} to ${p.destination} from the bank, then enter the reference.'),
            const SizedBox(height: 12),
            TextField(controller: utr, autofocus: true, decoration: const InputDecoration(labelText: 'UTR / UPI reference')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, utr.text.trim()), child: const Text('Mark as paid')),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    await _run(() => ref.read(apiProvider).payoutAction(p.id, 'mark-paid', utr: value));
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final date = DateFormat('d MMM, h:mm a');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Payouts', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(width: 16),
          FilledButton.icon(onPressed: _busy ? null : _createBatch, icon: const Icon(Icons.playlist_add), label: const Text('Create payout batch')),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(() async {
              final sent = await ref.read(apiProvider).sendPendingPayouts();
              if (mounted) showMessage(this.context, '${sent.length} payouts sent through RazorpayX');
            }),
            icon: const Icon(Icons.send),
            label: const Text('Send all through RazorpayX'),
          ),
          const SizedBox(width: 8),
          for (final (value, label) in const [('OPEN', 'Open'), ('PAID', 'Paid'), ('FAILED', 'Failed'), ('CANCELLED', 'Cancelled'), ('ALL', 'All')])
            ChoiceChip(label: Text(label), selected: _status == value, onSelected: (_) => setState(() => _status = value)),
        ]),
      ),
      Expanded(
        child: PagedList<PayoutView>(
          queryKey: (_status, _reload),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          separator: 8,
          fetch: (page) => api.payouts(status: _status, page: page),
          empty: const EmptyView(icon: Icons.account_balance_outlined, title: 'No payouts here'),
          itemBuilder: (context, p) => Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.account_balance_outlined)),
              title: Text('${p.vendorName} · ${formatInr(p.amountMinor)}'),
              subtitle: Text([
                p.status.label,
                p.destination,
                if (p.method != null) p.method == 'MANUAL' ? 'paid by hand' : 'RazorpayX',
                if (p.utr != null) 'ref ${p.utr}',
                if (p.failureReason != null) p.failureReason!,
                date.format(p.paidAt ?? p.createdAt),
              ].join(' · ')),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (p.status == PayoutStatus.PENDING) ...[
                  TextButton(onPressed: _busy ? null : () => _run(() => api.payoutAction(p.id, 'send')), child: const Text('Send')),
                  TextButton(onPressed: _busy ? null : () => _markPaid(p), child: const Text('Mark paid')),
                  IconButton(
                    tooltip: 'Cancel payout',
                    onPressed: _busy
                        ? null
                        : () async {
                            final reason = await askReason(context, title: 'Cancel payout', action: 'Cancel payout');
                            if (reason != null) await _run(() => api.payoutAction(p.id, 'cancel', reason: reason));
                          },
                    icon: const Icon(Icons.cancel_outlined),
                  ),
                ],
                if (p.status == PayoutStatus.PROCESSING)
                  TextButton(onPressed: _busy ? null : () => _run(() => api.payoutAction(p.id, 'refresh')), child: const Text('Check status')),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}
